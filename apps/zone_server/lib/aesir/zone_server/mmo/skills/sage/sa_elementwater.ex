defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaElementwater do
  @moduledoc """
  Elemental Change Water (SA_ELEMENTWATER). Overrides a monster's defense
  element to water for 30 minutes, consuming one Elemental Converter (12115).

  rAthena `db/re/skill_db.yml:1008`: quest skill, max level 1, magic, no damage,
  range 9, 2000ms fixed cast, 1000ms after-cast delay, 30 SP, one
  `Elemental_Water`, `Duration1` 1800000ms, `Status: ElementalChange`.

  `Aesir.ZoneServer.Mmo.Skills.Sage.ElementChange` holds the cast body shared with
  the earth, fire and wind variants and documents the deviations.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1008,
    name: :sa_elementwater,
    display_name: "Elemental Change Water",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :water,
    range: 9,
    sp_cost: [30],
    fixed_cast_time: [2_000],
    after_cast_delay: [1_000],
    duration: [1_800_000],
    status: :sc_elementalchange,
    item_cost: [%{id: 12_115, amount: 1}],
    quest_skill: true,
    quest_owner_job: :sage

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Sage.ElementChange

  @behaviour Active

  @impl Active
  defdelegate cast(caster, target, level, definition), to: ElementChange
end
