defmodule Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget do
  @moduledoc "Converts a targetable skill-unit cell into the combat target contract."

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell

  @default_combat %{
    def: 0,
    soft_def: 0,
    flee: 0,
    perfect_dodge: 0,
    element: {:neutral, 1},
    race: :formless,
    size: :medium
  }

  @doc "Builds the lightweight defender used for basic attacks against a cell."
  @spec to_combatant(Cell.t()) :: map()
  def to_combatant(%Cell{} = cell) do
    combat = Map.merge(@default_combat, Map.get(cell.state, :combat, %{}))

    %Combatant{
      unit_id: cell.cell_id,
      unit_type: :skill_unit,
      base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
      combat_stats: %{
        atk: 0,
        def: combat.def,
        hit: 0,
        flee: combat.flee,
        perfect_dodge: combat.perfect_dodge,
        matk: 0,
        mdef: Map.get(combat, :mdef, 0),
        soft_mdef: Map.get(combat, :soft_mdef, 0),
        soft_def: combat.soft_def
      },
      progression: %{base_level: 1, job_level: 1},
      element: combat.element,
      race: combat.race,
      size: combat.size,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 0,
      attack_delay_ms: 0,
      position: {cell.x, cell.y},
      map_name: cell.map_name
    }
    |> Map.put(:hp, cell.hp)
  end
end
