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
end
