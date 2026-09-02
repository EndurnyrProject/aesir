defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaLandprotector do
  @moduledoc """
  Land Protector (SA_LANDPROTECTOR), a magic-suppression ground field.

  Renewal data is from rAthena `db/re/skill_db.yml:8069-8125`: ID 288, layout
  size 3/3/4/4/5 (7x7 to 11x11), 165-345 second duration, 66-50 SP, one
  Blue_Gemstone (717) plus one Yellow_Gemstone (715), and `Interval: -1`
  (tickless). The suppression semantics live in `Skill.Unit.Manager`'s central
  placement path (`src/map/skill.cpp` `skill_cell_overlap` /
  `skill_unitsetting`): placing Land Protector destroys overlapping ground
  cells per cell, and later placements drop candidate cells that fall on it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 288,
    name: :sa_landprotector,
    requires: [],
    display_name: "Land Protector",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 2,
    unit_duration: [165_000, 210_000, 255_000, 300_000, 345_000],
    duration: [165_000, 210_000, 255_000, 300_000, 345_000],
    sp_cost: [66, 62, 58, 54, 50],
    cast_time: List.duplicate(4_000, 5),
    fixed_cast_time: List.duplicate(1_000, 5),
    item_cost: [%{id: 717, amount: 1}, %{id: 715, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.Sage.ElementField

  @layout_radii [3, 3, 4, 4, 5]

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    {:ok,
     %{
       cells: Layout.square(center, Enum.at(@layout_radii, level - 1)),
       state: %{land_protector: true},
       interval: 1_000,
       duration: Enum.at(definition().unit_duration, level - 1),
       path_check: true,
       lifecycle_policy: ElementField.policy()
     }}
  end

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{} = group, _rng), do: {:ok, %{group | next_tick_at: nil}}

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}
end
