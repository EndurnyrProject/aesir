defmodule Aesir.ZoneServer.Mmo.Combat.DefenseRateRoundingTest do
  @moduledoc """
  Status rate reductions scale DEF the reference's way: `def -= def * rate / 100`
  (`status_calc_def`), so the product truncates and an odd defense loses a point
  fewer than the `def * (100 + rate) / 100` grouping would.

  Provoke (`val3`), Fling (`val2`/`val3`), Freeze, Concentration and Signum
  Crucis all ride this channel.
  """

  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Stats.CombatStats

  defp defense(def, soft_def, modifiers) do
    defender = build(:mob_combatant, def: def, soft_def: soft_def)

    DamageInputs.physical_defense(
      defender,
      nil,
      :apply_status_def,
      :omit_equipment_def_ignore,
      modifiers
    )
  end

  test "a quarter off 101 DEF leaves 76, not 75" do
    assert defense(101, 101, %{def_rate: -25, def2_rate: -25}) == {76, 76}
  end

  test "a quarter on top of 101 DEF leaves 126" do
    assert defense(101, 101, %{def_rate: 25, def2_rate: 25}) == {126, 126}
  end

  test "a full reduction still reaches zero and a bonus joins before the rate" do
    assert defense(101, 101, %{def_rate: -100, def2_rate: -100}) == {0, 0}
    assert defense(100, 100, %{def_bonus: 1, def_rate: -25}) == {76, 100}
  end

  test "the multiplier channel keeps its own rounding before the rate" do
    assert defense(10, 10, %{defense_multiplier: 0.2, def_bonus: 50}) == {72, 12}
  end

  test "MDEF's rate uses the same shape" do
    stats = %Stats{
      combat_stats: %CombatStats{mdef: 101, soft_mdef: 0},
      modifiers: %Modifiers{status_effects: %{mdef_rate: -25}}
    }

    assert DamageInputs.status_window_magic_defense(stats) == {76, 0}
  end
end
