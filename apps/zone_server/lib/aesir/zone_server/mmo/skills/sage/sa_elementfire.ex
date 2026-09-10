defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaElementfire do
  @moduledoc """
  Elemental Change Fire (SA_ELEMENTFIRE). A quest skill that
  turns a monster's defence element into fire for 30 minutes, for 30 SP, an
  elemental converter, and a 1 s delay at 9 cells.

  Renewal: a 2 s fixed cast. Pre-renewal: a 2 s variable cast.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1018,
    name: :sa_elementfire,
    display_name: "Elemental Change Fire",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :fire,
    range: 9,
    sp_cost: [30],
    cast_time: [renewal: [], pre_renewal: [2_000]],
    fixed_cast_time: [renewal: [2_000], pre_renewal: []],
    after_cast_delay: [1_000],
    duration: [1_800_000],
    status: :sc_elementalchange,
    item_cost: [%{id: 12_114, amount: 1}],
    quest_skill: true,
    quest_owner_job: :sage

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Sage.ElementChange

  @behaviour Active

  @impl Active
  defdelegate cast(caster, target, level, definition), to: ElementChange
end
