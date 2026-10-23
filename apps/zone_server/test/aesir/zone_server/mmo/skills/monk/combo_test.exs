defmodule Aesir.ZoneServer.Mmo.Skills.Monk.ComboTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo

  test "opens a generation-tagged window that names no required target" do
    combo = Combo.open(Combo.new(), :quadruple, {:mob, 10}, 1_500)

    assert combo.stage == :quadruple
    assert combo.target == {:mob, 10}
    assert combo.deadline == 1_500
    assert combo.generation == 1
    assert Combo.open?(combo, :quadruple, 1_499)
    refute Combo.open?(combo, :thrust, 1_499)
    refute Combo.open?(combo, :quadruple, 1_500)
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

  test "check refuses silently outside the listed stages or after the deadline" do
    now = 1_000
    combo = Combo.open(Combo.new(), :chain_crush, {:mob, 42}, now + 500)

    assert :ok = Combo.check(combo, [:extremity, :chain_crush], now)
    assert {:error, :invalid_combo} = Combo.check(combo, [:extremity, :tiger_fist], now)
    assert {:error, :invalid_combo} = Combo.check(combo, :chain_crush, now + 500)
    assert {:error, :invalid_combo} = Combo.check(Combo.new(), :chain_crush, now)
  end

  describe "use_target/5" do
    setup do
      now = System.monotonic_time(:millisecond)
      open = Combo.open(Combo.new(), :quadruple, {:mob, 42}, now + 60_000)
      %{caster: %{character_id: 1, combo: open}}
    end

    test "aims a follow-up at the attack target while its window opens and its conditions pass",
         %{caster: caster} do
      assert Combo.use_target(caster, 272, {:unit, 7}, 9, fn -> true end) == {:unit, 9}
      assert Combo.use_target(caster, 271, {:unit, 7}, 9, fn -> true end) == {:unit, 9}
    end

    test "without an attack target a self-aimed use has no target and a named unit stays",
         %{caster: caster} do
      assert Combo.use_target(caster, 272, :self, nil, fn -> true end) == {:unit, 0}
      assert Combo.use_target(caster, 272, {:unit, 7}, nil, fn -> true end) == {:unit, 7}
    end

    test "outside a passing window only a self-aimed follow-up takes the attack target",
         %{caster: caster} do
      assert Combo.use_target(caster, 273, :self, 9, fn -> false end) == {:unit, 9}
      assert Combo.use_target(caster, 273, {:unit, 7}, 9, fn -> false end) == {:unit, 7}
      assert Combo.use_target(caster, 271, :self, 9, fn -> false end) == :self
    end

    test "leaves other skills alone", %{caster: caster} do
      assert Combo.use_target(caster, 5, :self, 9, fn -> true end) == :self
    end
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

    test "Raging Quadruple Blow opens Thrust's window with a sphere and Thrust known" do
      assert Combo.follow_up_stage(:quadruple, ctx([273], 1)) == :thrust
      assert Combo.follow_up_stage(:quadruple, ctx([273], 0)) == :idle
      assert Combo.follow_up_stage(:quadruple, ctx([], 5)) == :idle
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
