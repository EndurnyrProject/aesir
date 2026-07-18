defmodule Aesir.ZoneServer.Mmo.Skills.WzIcewall do
  @moduledoc """
  Ice Wall (WZ_ICEWALL), a five-cell, directional, destructible terrain wall.

  Each cell starts with `200 + 200 * level` HP and loses 50 HP every second,
  matching rAthena's skill-unit timer. The unit manager owns the cell mutation,
  visibility updates, target indexes, and terrain cleanup; this skill only
  describes its placement.

  rAthena forbids casting Ice Wall while the caster is under Volcano
  (`status.cpp:2194`); `validate/4` rejects it before SP is charged.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 87,
    name: :wz_icewall,
    display_name: "Ice Wall",
    max_level: 10,
    target_type: :ground,
    damage_type: :no_damage,
    range: 9,
    element: :water,
    hit_interval: 1_000,
    unit_duration: [8_000, 12_000, 16_000, 20_000, 24_000, 28_000, 32_000, 36_000, 40_000, 44_000],
    cast_time: List.duplicate(0, 10),
    fixed_cast_time: List.duplicate(0, 10),
    sp_cost: List.duplicate(20, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @behaviour Ground
  @cell_decay 50
  @wall_half 2

  @doc false
  @spec validate(map(), term(), pos_integer(), struct()) :: :ok | {:error, :volcano_active}
  def validate(%{character_id: caster_id}, _target, _level, _definition) do
    if StatusStorage.has_status?(:player, caster_id, :sc_volcano),
      do: {:error, :volcano_active},
      else: :ok
  end

  @impl Ground
  def on_place(%Group{center: center, level: level} = group) do
    hp = 200 + 200 * level
    definition = definition()
    cells = Layout.line(center, wall_direction(group), @wall_half)

    {:ok,
     %{
       cells: cells,
       cell_attrs:
         Map.new(cells, fn cell ->
           {cell,
            %{
              hp: hp,
              max_hp: hp,
              flags: [:targetable, :blocks_movement, :blocks_projectiles],
              state: %{exclusive_terrain: true}
            }}
         end),
       state: %{cell_decay: @cell_decay, exclusive_terrain: true},
       path_check: true,
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @spec wall_direction(Group.t()) :: {integer(), integer()}
  defp wall_direction(%Group{center: {cx, cy}, origin: {px, py}}) do
    case {sign(cx - px), sign(cy - py)} do
      {0, 0} -> {1, 0}
      {fx, fy} -> {-fy, fx}
    end
  end

  defp wall_direction(%Group{origin: nil}), do: {1, 0}

  @spec sign(integer()) :: -1 | 0 | 1
  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0
end
