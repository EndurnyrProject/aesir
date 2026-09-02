defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaVolcano do
  @moduledoc """
  Volcano (SA_VOLCANO), the Sage's Fire element field.

  Renewal data is from rAthena `db/re/skill_db.yml:5768-5817`: ID 285, `Layout: 3`
  (7x7), range 2, 60-300 second duration, 48-40 SP, 4,000 ms variable plus
  1,000 ms fixed cast, one Blue_Gemstone (717), `PathCheck: true` and
  `Interval: -1` (tickless).

  `src/map/skill.cpp:6517-6525` applies `SC_VOLCANO` to any `bl` that occupies
  the field, so `field_support/1` filters nothing: allies, enemies and the caster
  all get it. Per-caster exclusivity against the rest of the element-field family
  is declared through the lifecycle policy and enforced centrally by
  `Skill.Unit.Manager`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 285,
    name: :sa_volcano,
    display_name: "Volcano",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 2,
    element: :fire,
    unit_duration: [60_000, 120_000, 180_000, 240_000, 300_000],
    duration: [60_000, 120_000, 180_000, 240_000, 300_000],
    sp_cost: [48, 46, 44, 42, 40],
    cast_time: List.duplicate(4_000, 5),
    fixed_cast_time: List.duplicate(1_000, 5),
    item_cost: [%{id: 717, amount: 1}],
    status: :sc_volcano

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Sage.ElementField

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
  def field_support(%Group{level: level}), do: ElementField.support(:sc_volcano, level)
end
