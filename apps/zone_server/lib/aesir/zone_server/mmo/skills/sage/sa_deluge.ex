defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaDeluge do
  @moduledoc """
  Deluge (SA_DELUGE). A tickless 7x7 water field lasting 60 s per level that
  supports every occupant with the water field status, one field per caster
  across the element-field family (a swap inherits the remaining duration). The
  status adds 10, 14, 17, 19, or 20 points to the holder's water attack: as
  ratio points on the element table in renewal and as a damage multiplier in
  pre-renewal. Deluge raises max HP by 5, 9, 12, 14, or 15% in both modes; pre-renewal grants it only to water-element holders.

  Renewal: a 4 s cast plus 1 s fixed and a Blue Gemstone. Pre-renewal: a 5 s cast
  and a Yellow Gemstone. Both cost 48 down to 40 SP at 2 cells.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 286,
    name: :sa_deluge,
    display_name: "Deluge",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 2,
    element: :water,
    unit_duration: [60_000, 120_000, 180_000, 240_000, 300_000],
    duration: [60_000, 120_000, 180_000, 240_000, 300_000],
    sp_cost: [48, 46, 44, 42, 40],
    cast_time: [renewal: List.duplicate(4_000, 5), pre_renewal: List.duplicate(5_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    item_cost: [renewal: [%{id: 717, amount: 1}], pre_renewal: [%{id: 715, amount: 1}]],
    status: :sc_deluge

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Sage.ElementField

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    placement = ElementField.placement(center, level)
    cell_attrs = Map.new(placement.cells, &{&1, %{flags: [:consumable_water]}})

    {:ok, Map.put(placement, :cell_attrs, cell_attrs)}
  end

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{} = group, _rng), do: {:ok, %{group | next_tick_at: nil}}

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{level: level}), do: ElementField.support(:sc_deluge, level)
end
