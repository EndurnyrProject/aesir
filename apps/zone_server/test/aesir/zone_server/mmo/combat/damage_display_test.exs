defmodule Aesir.ZoneServer.Mmo.Combat.DamageDisplayTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat.DamageDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(UnitRegistry, :get_unit, fn _type, _id -> {:error, :not_found} end)
    :ok
  end

  defp dealt(damage, damage2, type),
    do: %DamageDealt{target_id: 100, damage: damage, damage2: damage2, div: 1, type: type}

  defp skill(damage, div, type),
    do: %SkillDamage{target_id: 100, damage: damage, div: div, type: type}

  test "a damaging hit on an enduring target shows its endure form" do
    StatusStorage.apply_status(:mob, 100, :sc_endure, val1: 1)

    assert %DamageDealt{type: 4} = DamageDisplay.finalize(dealt(0, 10, 10), :mob)
    assert %SkillDamage{type: 9} = DamageDisplay.finalize(skill(30, 3, 6), :mob)
    assert %SkillDamage{type: 14} = DamageDisplay.finalize(skill(30, 1, 5), :mob)
  end

  test "a hit dealing nothing keeps its type" do
    StatusStorage.apply_status(:mob, 100, :sc_endure, val1: 1)

    assert %DamageDealt{type: 0} = DamageDisplay.finalize(dealt(0, 0, 0), :mob)
  end

  test "a target that does not endure keeps the type" do
    assert %DamageDealt{type: 10} = DamageDisplay.finalize(dealt(50, 0, 10), :mob)
  end
end
