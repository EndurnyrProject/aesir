defmodule Aesir.ZoneServer.Mmo.Skills.WzWaterball do
  @moduledoc "Water Ball (WZ_WATERBALL) consumes nearby water into an invisible hit sequence."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 86,
    name: :wz_waterball,
    display_name: "Water Ball",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :water,
    range: 9,
    cast_time: [640, 1_280, 1_920, 2_560, 3_200],
    fixed_cast_time: [160, 320, 480, 640, 800],
    sp_cost: [15, 20, 20, 25, 25]

  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.TargetState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @behaviour Ground

  @interval 150
  @duration 10_000

  @impl Active
  def cast(
        %{character_id: caster_id, map_name: map_name, x: x, y: y} = caster,
        {:unit, target_id},
        level,
        _definition
      ) do
    with {:ok, %{unit_type: target_type}} <- Combat.resolve_combatant(target_id),
         :ok <- require_water(map_name, x, y),
         {:ok, _group} <-
           Manager.register_water_ball_sequence(
             %Group{
               group_id: System.unique_integer([:monotonic, :positive]),
               skill_id: definition().id,
               skill_name: :wz_waterball,
               level: level,
               caster_id: caster_id,
               caster_type: :player,
               target_id: target_id,
               target_type: target_type,
               map_name: map_name,
               center: {x, y},
               interval: @interval,
               expires_at: System.monotonic_time(:millisecond) + @duration,
               next_tick_at: System.monotonic_time(:millisecond),
               visible?: false,
               state: %{water_ball_sequence: true}
             },
             unprotected_sources(map_name, {x, y}, level)
           ) do
      {:ok, caster}
    end
  end

  @impl Ground
  def on_place(_group), do: raise("Water Ball sequences are registered by the manager")

  @impl Ground
  def on_interval(%Group{map_name: map_name} = group, _now) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_id),
         :ok <- living_target(group.target_type, group.target_id),
         {:ok, {target_x, target_y, ^map_name}} <-
           SpatialIndex.get_unit_position(group.target_type, group.target_id),
         true <- LineOfSight.clear?(map_name, group.center, {target_x, target_y}) do
      Combat.apply_skill_unit_damage(
        caster,
        group.target_type,
        group.target_id,
        group.skill_id,
        group.level,
        :water,
        100 + 30 * group.level
      )

      {:ok, mark_shot(group, true)}
    else
      false -> {:ok, mark_shot(group, false)}
      {:error, _reason} -> {:expire, group}
      {:ok, {_x, _y, _other_map}} -> {:expire, group}
    end
  end

  defp mark_shot(%Group{state: state} = group, fired?),
    do: %{group | state: Map.put(state, :water_ball_fired, fired?)}

  defp living_target(unit_type, unit_id) do
    with {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(unit_type, unit_id),
         true <- TargetState.living?(state) do
      :ok
    else
      _ -> {:error, :target_dead}
    end
  end

  defp require_water(map_name, x, y) do
    case MapCell.water_source(map_name, x, y) do
      %MapCell.WaterSource{origin: origin} when origin in [:base, :skill_unit] ->
        if Storage.land_protected?(map_name, x, y),
          do: {:error, :water_required},
          else: :ok

      _ ->
        {:error, :water_required}
    end
  end

  defp unprotected_sources(map_name, center, level) do
    center
    |> Layout.square(water_radius(level))
    |> Enum.reject(fn {x, y} -> Storage.land_protected?(map_name, x, y) end)
  end

  defp water_radius(1), do: 0
  defp water_radius(level) when level in 2..3, do: 1
  defp water_radius(_level), do: 2
end
