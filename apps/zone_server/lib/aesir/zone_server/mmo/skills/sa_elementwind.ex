defmodule Aesir.ZoneServer.Mmo.Skills.SaElementwind do
  @moduledoc """
  Elemental Change Wind (SA_ELEMENTWATER). Overrides a monster's defense
  element to wind for 30 minutes, consuming one Elemental Converter (12117).

  rAthena `db/re/skill_db.yml:1019`: quest skill, max level 1, magic, no damage,
  range 9, 2000ms fixed cast, 1000ms after-cast delay, 30 SP, one
  `Elemental_Wind`, `Duration1` 1800000ms, `Status: ElementalChange`.

  `Aesir.ZoneServer.Mmo.Skills.ElementChange` holds the cast body shared with
  the water, earth and fire variants and documents the deviations.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1019,
    name: :sa_elementwind,
    display_name: "Elemental Change Wind",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    element: :wind,
    range: 9,
    sp_cost: [30],
    fixed_cast_time: [2_000],
    after_cast_delay: [1_000],
    duration: [1_800_000],
    status: :sc_elementalchange,
    item_cost: [%{id: 12_117, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.ElementChange

  @behaviour Active

  @impl Active
  defdelegate cast(caster, target, level, definition), to: ElementChange
end
