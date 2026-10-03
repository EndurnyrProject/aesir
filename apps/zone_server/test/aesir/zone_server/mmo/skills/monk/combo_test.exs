defmodule Aesir.ZoneServer.Mmo.Skills.Monk.ComboTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo

  test "opens a generation-tagged window for one target" do
    combo = Combo.open(Combo.new(), :quadruple, {:mob, 10}, 1_500)

    assert combo.stage == :quadruple
    assert combo.target == {:mob, 10}
    assert combo.deadline == 1_500
    assert combo.generation == 1
    assert Combo.current?(combo, :quadruple, {:mob, 10}, 1_499)
    refute Combo.current?(combo, :quadruple, {:mob, 11}, 1_499)
    refute Combo.current?(combo, :quadruple, {:mob, 10}, 1_500)
  end

  test "advance requires the current stage, target, and deadline" do
    combo = Combo.open(Combo.new(), :quadruple, {:player, 20}, 2_000)

    assert {:ok, advanced} =
             Combo.advance(combo, :quadruple, :thrust, {:player, 20}, 2_500, 1_999)

    assert advanced.stage == :thrust
    assert advanced.target == {:player, 20}
    assert advanced.generation == 2

    assert {:error, :invalid_combo} =
             Combo.advance(combo, :thrust, :quadruple, {:player, 20}, 2_500, 1_999)

    assert {:error, :invalid_combo} =
             Combo.advance(combo, :quadruple, :thrust, {:player, 21}, 2_500, 1_999)

    assert {:error, :invalid_combo} =
             Combo.advance(combo, :quadruple, :thrust, {:player, 20}, 2_500, 2_000)
  end

  test "matching expiry and explicit cancellation invalidate stale generations" do
    combo = Combo.open(Combo.new(), :quadruple, {:mob, 10}, 1_500)

    assert Combo.expire(combo, combo.generation + 1, 2_000) == combo
    assert Combo.expire(combo, combo.generation, 1_499) == combo

    expired = Combo.expire(combo, combo.generation, 1_500)
    assert expired.stage == :idle
    assert expired.target == nil
    assert expired.deadline == nil
    assert expired.generation == 2

    reopened = Combo.open(expired, :quadruple, {:mob, 11}, 3_000)
    cancelled = Combo.cancel(reopened)
    assert cancelled.stage == :idle
    assert cancelled.generation == reopened.generation + 1
    assert Combo.cancel(cancelled) == cancelled
  end

  test "validate returns the retained typed target only for the current stage and id" do
    now = 1_000
    combo = Combo.open(Combo.new(), :quadruple, {:mob, 42}, now + 500)

    assert {:ok, {:mob, 42}} = Combo.validate(combo, :quadruple, 42, now)
    assert {:error, :invalid_combo} = Combo.validate(combo, :thrust, 42, now)
    assert {:error, :invalid_combo} = Combo.validate(combo, :quadruple, 43, now)
    assert {:error, :invalid_combo} = Combo.validate(combo, :quadruple, 42, now + 500)
  end

  test "typed validation rejects a reused id owned by another unit type" do
    now = 1_000
    combo = Combo.open(Combo.new(), :quadruple, {:mob, 42}, now + 500)

    assert {:ok, {:mob, 42}} = Combo.validate(combo, :quadruple, {:mob, 42}, now)
    assert {:error, :invalid_combo} = Combo.validate(combo, :quadruple, {:player, 42}, now)
  end

  test "validate and advance accept any stage from a list" do
    now = 1_000
    combo = Combo.open(Combo.new(), :chain_crush, {:mob, 42}, now + 500)

    assert {:ok, {:mob, 42}} = Combo.validate(combo, [:extremity, :chain_crush], 42, now)
    assert {:error, :invalid_combo} = Combo.validate(combo, [:extremity, :tiger_fist], 42, now)
    assert Combo.current?(combo, [:extremity, :chain_crush], {:mob, 42}, now)

    assert {:ok, %Combo{stage: :tiger_fist}} =
             Combo.advance(combo, [:extremity, :chain_crush], :tiger_fist, {:mob, 42}, 2_000, now)
  end

  describe "follow_up_stage/2" do
    test "Raging Thrust opens the extremity window for each Champion follow-up" do
      assert Combo.follow_up_stage(:thrust, ctx([371], 1)) == :extremity
      assert Combo.follow_up_stage(:thrust, ctx([371], 0)) == :idle
      assert Combo.follow_up_stage(:thrust, ctx([372], 2)) == :extremity
      assert Combo.follow_up_stage(:thrust, ctx([372], 1)) == :idle
      assert Combo.follow_up_stage(:thrust, ctx([271], 4, true)) == :extremity
      assert Combo.follow_up_stage(:thrust, ctx([271], 4, false)) == :idle
      assert Combo.follow_up_stage(:thrust, ctx([271], 3, true)) == :idle
      assert Combo.follow_up_stage(:thrust, ctx([], 5, true)) == :idle
    end

    test "Glacier Fist opens its window only toward Chain Crush" do
      assert Combo.follow_up_stage(:tiger_fist, ctx([372], 2)) == :tiger_fist
      assert Combo.follow_up_stage(:tiger_fist, ctx([372], 1)) == :idle
      assert Combo.follow_up_stage(:tiger_fist, ctx([271, 371], 5, true)) == :idle
    end

    test "Chain Crush opens its window toward Asura in every mode" do
      assert Combo.follow_up_stage(:chain_crush, ctx([271], 1, true)) == :chain_crush
      assert Combo.follow_up_stage(:chain_crush, ctx([271], 0, true)) == :idle
      assert Combo.follow_up_stage(:chain_crush, ctx([271], 1, false)) == :idle
    end

    @tag game_mode: :renewal
    test "renewal Chain Crush never opens toward Glacier Fist" do
      assert Combo.follow_up_stage(:chain_crush, ctx([371], 5)) == :idle
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal Chain Crush loops back into Glacier Fist" do
      assert Combo.follow_up_stage(:chain_crush, ctx([371], 1)) == :chain_crush
      assert Combo.follow_up_stage(:chain_crush, ctx([371], 0)) == :idle
    end
  end

  defp ctx(known, spheres, fury? \\ false) do
    %{learned: Map.new(known, &{&1, 5}), spheres: spheres, fury?: fury?}
  end
end
