defmodule Aesir.ZoneServer.Mmo.Combat.CombatantTest do
  @moduledoc """
  Tests for the Combatant struct and its helper functions.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats

  describe "new/1" do
    test "creates valid combatant with all required fields" do
      attrs = %{
        unit_id: 1001,
        unit_type: :player,
        base_stats: %BaseStats{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
        combat_stats: %CombatStats{atk: 50, def: 20, hit: 100, flee: 80, perfect_dodge: 5},
        progression: %{base_level: 10, job_level: 1},
        element: :neutral,
        race: :human,
        size: :medium,
        weapon: %{type: :sword, element: :neutral, size: :all}
      }

      assert {:ok, combatant} = Combatant.new(attrs)
      assert combatant.unit_id == 1001
      assert combatant.unit_type == :player
      assert combatant.base_stats.str == 10
      assert combatant.combat_stats.atk == 50
      assert combatant.progression.base_level == 10
    end
  end
end
