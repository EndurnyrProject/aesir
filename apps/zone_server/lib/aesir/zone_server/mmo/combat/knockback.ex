defmodule Aesir.ZoneServer.Mmo.Combat.Knockback do
  @moduledoc """
  Collision-aware knockback resolution for combat units.

  Walks a unit outward away from a source cell one step at a time, stopping at
  the last walkable cell before a wall, then routes the landing-cell update
  through the owning session and broadcasts the slide to nearby players.
  """

  alias Aesir.Net.Knockback, as: KnockbackPacket
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Session, as: UnitSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.TargetState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Knocks a unit back away from `{from_x, from_y}`, collision-aware.

  Walks the unit outward one cell at a time (8-dir, away from the source through
  its current cell) up to `distance` cells, stopping at the last walkable cell
  before a wall (rAthena `unit_blown`). Updates the unit state, the spatial index
  and the registry, then broadcasts `Knockback` to nearby players so they slide
  the unit to its landing cell.

  Bosses are immune: their position is resolved and returned unchanged, with
  no movement and no broadcast.

  Returns `:ok` for skill units, `{:ok, {dst_x, dst_y}}` with the final cell
  (unchanged if it could not move, or if the defender is a boss), or
  `{:error, reason}` if the unit or its map could not be resolved.
  """
  @spec knockback(atom(), integer(), integer(), integer(), non_neg_integer()) ::
          :ok | {:ok, {integer(), integer()}} | {:error, atom()}
  def knockback(:skill_unit, _unit_id, _from_x, _from_y, _distance), do: :ok

  def knockback(unit_type, unit_id, from_x, from_y, distance) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         :ok <- ensure_living_unit(unit_type, unit_id),
         {:ok, _map} <- MapCache.get(map_name) do
      if boss?(unit_type, unit_id) do
        {:ok, {x, y}}
      else
        do_knockback(unit_type, unit_id, x, y, from_x, from_y, distance, map_name)
      end
    end
  end

  defp do_knockback(unit_type, unit_id, x, y, from_x, from_y, distance, map_name) do
    {dx, dy} = {sign(x - from_x), sign(y - from_y)}
    {dst_x, dst_y} = blow_path(map_name, x, y, dx, dy, distance)

    if {dst_x, dst_y} != {x, y} do
      move_unit(unit_type, unit_id, dst_x, dst_y, map_name)
      broadcast_blownback(unit_id, dst_x, dst_y, map_name)
      {:ok, {dst_x, dst_y}}
    else
      {:ok, {dst_x, dst_y}}
    end
  end

  defp ensure_living_unit(unit_type, unit_id) do
    if living_unit?(unit_type, unit_id), do: :ok, else: {:error, :target_dead}
  end

  defp living_unit?(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> TargetState.living?(state)
      _ -> false
    end
  end

  defp boss?(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {module, state, _pid}} -> module.is_boss?(state)
      {:error, :not_found} -> false
    end
  end

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0

  # No direction (unit on top of source): nowhere to blow.
  defp blow_path(_map_name, x, y, 0, 0, _distance), do: {x, y}

  # Step outward, keeping the last walkable cell reached.
  defp blow_path(map_name, x, y, dx, dy, distance) do
    Enum.reduce_while(1..distance//1, {x, y}, fn _step, {cx, cy} ->
      {nx, ny} = {cx + dx, cy + dy}

      if Cell.traversable?(map_name, nx, ny) do
        {:cont, {nx, ny}}
      else
        {:halt, {cx, cy}}
      end
    end)
  end

  # Routes the landing-cell update through the owning session so it is the single
  # writer: the session updates its live `game_state` (position + stop walking)
  # and re-syncs the spatial index/registry/dirty set via `Movement.set_position`,
  # which prevents a knocked-back moving unit's own next tick from overwriting the
  # blow. Falls back to a direct write when the owning process can't be resolved.
  defp move_unit(unit_type, unit_id, x, y, map_name) do
    case owning_pid(unit_type, unit_id) do
      {:ok, pid} -> UnitSession.knock_back(unit_type, pid, x, y)
      :error -> move_unit_direct(unit_type, unit_id, x, y, map_name)
    end
  end

  defp owning_pid(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> {:ok, pid}
      _ -> :error
    end
  end

  defp move_unit_direct(unit_type, unit_id, x, y, map_name) do
    with {:ok, {module, state, _pid}} <- UnitRegistry.get_unit(unit_type, unit_id) do
      UnitRegistry.update_unit_state(unit_type, unit_id, module.update_position(state, x, y))
    end

    SpatialIndex.update_unit_position(unit_type, unit_id, x, y, map_name)
    Movement.mark_dirty(map_name, unit_type, unit_id, 0)
  end

  defp broadcast_blownback(unit_id, dst_x, dst_y, map_name) do
    packet = %KnockbackPacket{unit_id: unit_id, dst_x: dst_x, dst_y: dst_y}
    Broadcast.to_in_range(map_name, dst_x, dst_y, Config.view_range(), packet)
  end
end
