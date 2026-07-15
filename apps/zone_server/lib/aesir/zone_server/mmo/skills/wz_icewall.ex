defmodule Aesir.ZoneServer.Mmo.Skills.WzIcewall do
  @moduledoc """
  Ice Wall (WZ_ICEWALL), a five-cell, directional, destructible terrain wall.

  Each cell starts with `200 + 200 * level` HP and loses 50 HP every second,
  matching rAthena's skill-unit timer. The unit manager owns the cell mutation,
  visibility updates, target indexes, and terrain cleanup; this skill only
  describes its placement.
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

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout

  @behaviour Ground
  @cell_decay 50
  @wall_half 2

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
              state: %{terrain_source: :icewall}
            }}
         end),
       state: %{cell_decay: @cell_decay, terrain_source: :icewall},
       path_check: true,
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @spec wall_direction(Group.t()) :: {integer(), integer()}
  defp wall_direction(%Group{center: {cx, cy}, caster_id: caster_id}) do
    case Combat.resolve_combatant(caster_id) do
      {:ok, %{position: {px, py}}} ->
        case {sign(cx - px), sign(cy - py)} do
          {0, 0} -> {1, 0}
          {fx, fy} -> {-fy, fx}
        end

      {:error, _reason} ->
        {1, 0}
    end
  end

  @spec sign(integer()) :: -1 | 0 | 1
  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0
end
