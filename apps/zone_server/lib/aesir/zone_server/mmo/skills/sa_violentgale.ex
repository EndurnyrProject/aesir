defmodule Aesir.ZoneServer.Mmo.Skills.SaViolentgale do
  @moduledoc """
  Violent Gale (SA_VIOLENTGALE), the Sage's Wind element field.

  Renewal data is from rAthena `db/re/skill_db.yml:5868-5917`: ID 287, `Layout: 3`
  (7x7), range 2, 60-300 second duration, 48-40 SP, 4,000 ms variable plus
  1,000 ms fixed cast, one Blue_Gemstone (717), `PathCheck: true` and
  `Interval: -1` (tickless).

  `src/map/skill.cpp:6517-6525` applies `SC_VIOLENTGALE` to any `bl` that occupies
  the field, so `field_support/1` filters nothing. Per-caster exclusivity against
  the rest of the element-field family is declared through the lifecycle policy
  and enforced centrally by `Skill.Unit.Manager`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 287,
    name: :sa_violentgale,
    display_name: "Violent Gale",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 2,
    element: :wind,
    unit_duration: [60_000, 120_000, 180_000, 240_000, 300_000],
    duration: [60_000, 120_000, 180_000, 240_000, 300_000],
    sp_cost: [48, 46, 44, 42, 40],
    cast_time: List.duplicate(4_000, 5),
    fixed_cast_time: List.duplicate(1_000, 5),
    item_cost: [%{id: 717, amount: 1}],
    status: :sc_violentgale

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.ElementField

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}),
    do: {:ok, ElementField.placement(center, level)}

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{} = group, _rng), do: {:ok, %{group | next_tick_at: nil}}

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{level: level}), do: ElementField.support(:sc_violentgale, level)
end
