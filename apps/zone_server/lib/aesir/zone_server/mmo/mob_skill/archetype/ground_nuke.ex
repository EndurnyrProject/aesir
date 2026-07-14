defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundNuke do
  @moduledoc """
  Ground-targeted AoE magic damage (`WZ_METEOR`, `WZ_STORMGUST`,
  `NPC_GROUNDATTACK`, ...).

  `apply/4` builds a mob-cast `Skill.Unit.Group` directly and registers it with
  `Skill.Unit.Manager` — it cannot go through the player `Skill.Unit.place/4`,
  which resolves per-skill modules from the player catalog. The stored group
  carries the constant `skill_name: :mob_ground_nuke`, so no player-catalog
  lookup (movement trigger, `Skill.Unit.destroy/1`) ever matches it.

  This module is also the group's tick handler: `Skill.Unit.Manager`
  dispatches every `caster_type: :mob` group here. `on_interval/2` follows the
  `Skill.Ground` contract (minus `on_place/1` — placement happens in `apply/4`):
  it resolves the mob caster once per tick, skipping the tick cleanly when the
  mob is gone, and applies renewal magic damage to every player standing on a
  footprint cell. The group expires via the unit manager's normal reaping.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  # NOTE: one generic timing/ratio for every mob ground nuke (Storm Gust's
  # 450ms/4500ms unit and its renewal ratio 70 + 50 * level); per-skill tuning
  # can move into the catalog params when a skill needs it.
  @interval 450
  @duration 4_500

  # The rAthena `around*` code sizes the footprint: the digit is the radius,
  # plain `around` gets the classic 5x5.
  @radius_by_area %{
    around: 2,
    around1: 1,
    around2: 2,
    around3: 3,
    around4: 4,
    around5: 1,
    around6: 2,
    around7: 3,
    around8: 4
  }

  @impl true
  def apply(%MobState{} = caster, {:ground, x, y, area}, params, level) do
    with {:ok, radius} <- radius_for(area),
         {:ok, cells} <- footprint(caster.map_name, {x, y}, radius) do
      now = System.monotonic_time(:millisecond)

      group = %Group{
        group_id: System.unique_integer([:monotonic, :positive]),
        skill_id: params.skill_id,
        skill_name: :mob_ground_nuke,
        level: level,
        caster_id: caster.instance_id,
        caster_type: :mob,
        map_name: caster.map_name,
        center: {x, y},
        cells: cells,
        next_tick_at: now + @interval,
        expires_at: now + @duration,
        interval: @interval,
        state: %{element: params.element, radius: radius}
      }

      :ok = Manager.register(group)
      broadcast_groundskill(group)
      :ok
    end
  end

  def apply(%MobState{}, _target, _params, _level), do: {:error, :invalid_target}

  @doc """
  Per-interval tick for a mob-cast ground group (`Skill.Ground` contract).

  Resolves the caster's combatant, then hits every player standing on a
  footprint cell with magic damage of the group's element. When the caster is
  gone (despawned, dead) the tick is skipped without damage; the group still
  expires on schedule.
  """
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{} = group, _now) do
    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        Enum.each(occupants(group), &hit(group, caster, &1))
        {:ok, group}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  @doc """
  Expiry hook (`Skill.Ground` contract). No per-group cleanup is needed.
  """
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{}), do: :ok

  defp radius_for(area) do
    case Map.fetch(@radius_by_area, area) do
      {:ok, radius} -> {:ok, radius}
      :error -> {:error, {:unknown_area, area}}
    end
  end

  defp footprint(map_name, center, radius) do
    with {:ok, map_data} <- map_data(map_name) do
      case Enum.filter(Layout.square(center, radius), &walkable?(map_data, &1)) do
        [] -> {:error, :no_walkable_cells}
        cells -> {:ok, cells}
      end
    end
  end

  defp walkable?(map_data, {x, y}), do: MapData.walkable?(map_data, x, y)

  defp map_data(map_name) do
    case MapCache.get(map_name) do
      {:ok, map_data} -> {:ok, map_data}
      {:error, :not_found} -> {:error, :unknown_map}
    end
  end

  # The spatial index filters by Manhattan distance (a diamond), so a query of
  # 2 * radius covers the Chebyshev square before the exact cell filter.
  defp occupants(%Group{center: {cx, cy}, state: %{radius: radius}} = group) do
    :player
    |> SpatialIndex.get_units_in_range(group.map_name, cx, cy, radius * 2)
    |> Enum.filter(&on_footprint?(group, &1))
  end

  defp on_footprint?(%Group{cells: cells}, player_id) do
    case SpatialIndex.get_unit_position(:player, player_id) do
      {:ok, {x, y, _map}} -> {x, y} in cells
      {:error, :not_found} -> false
    end
  end

  defp hit(%Group{} = group, caster, player_id) do
    Combat.apply_skill_unit_damage(
      caster,
      :player,
      player_id,
      group.skill_id,
      group.level,
      group.state.element,
      skill_ratio(group.level)
    )
  end

  defp skill_ratio(level), do: 70 + 50 * level

  defp broadcast_groundskill(%Group{center: {x, y}} = group) do
    packet = %GroundSkill{
      skill_id: group.skill_id,
      src_id: group.caster_id,
      level: group.level,
      x: x,
      y: y,
      server_tick: ServerTick.now()
    }

    Broadcast.to_in_range(group.map_name, x, y, Config.view_range(), packet)
  end
end
