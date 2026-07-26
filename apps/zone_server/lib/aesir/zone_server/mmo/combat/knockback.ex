defmodule Aesir.ZoneServer.Mmo.Combat.Knockback do
  @moduledoc """
  Collision-aware, session-owned combat displacement.

  This module computes a landing cell from the current spatial snapshot. The
  target session validates that snapshot and owns movement commitment and
  publication.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type result :: :ok | {:ok, {integer(), integer()}} | {:error, atom()}

  @doc """
  Requests collision-aware movement away from `{from_x, from_y}`.
  """
  @spec knockback(atom(), integer(), integer(), integer(), non_neg_integer()) :: result()
  def knockback(:skill_unit, _unit_id, _from_x, _from_y, _distance), do: :ok

  def knockback(unit_type, unit_id, from_x, from_y, distance) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         {:ok, {module, state, pid}} <- displacement_owner(unit_type, unit_id),
         :ok <- ensure_living(state),
         {:ok, _map} <- MapCache.get(map_name) do
      if module.is_boss?(state) do
        {:ok, {x, y}}
      else
        {dx, dy} = {sign(x - from_x), sign(y - from_y)}
        destination = blow_path(map_name, x, y, dx, dy, distance)
        request_displacement(pid, {x, y, map_name}, destination)
      end
    end
  end

  @doc """
  Requests collision-aware movement toward `{target_x, target_y}`.
  """
  @spec pull_to(atom(), integer(), integer(), integer()) :: result()
  def pull_to(:skill_unit, _unit_id, _target_x, _target_y), do: :ok

  def pull_to(unit_type, unit_id, target_x, target_y) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         {:ok, {module, state, pid}} <- displacement_owner(unit_type, unit_id),
         :ok <- ensure_living(state),
         {:ok, map_data} <- MapCache.get(map_name) do
      if module.is_boss?(state) do
        {:ok, {x, y}}
      else
        destination = pull_path(map_data, {x, y}, {target_x, target_y})
        request_displacement(pid, {x, y, map_name}, destination)
      end
    end
  end

  @doc """
  Requests an authoritative self-relocation without hostile boss immunity.
  """
  @spec relocate(atom(), integer(), integer(), integer()) :: result()
  def relocate(unit_type, unit_id, x, y) do
    with {:ok, {expected_x, expected_y, map_name}} <-
           SpatialIndex.get_unit_position(unit_type, unit_id),
         {:ok, {_module, state, pid}} <- displacement_owner(unit_type, unit_id),
         :ok <- ensure_living(state),
         {:ok, _map} <- MapCache.get(map_name) do
      GenServer.cast(
        pid,
        {:movement, {:relocate, expected_x, expected_y, map_name, x, y}}
      )

      {:ok, {x, y}}
    end
  end

  defp displacement_owner(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {module, state, pid}} when is_pid(pid) ->
        if Process.alive?(pid),
          do: {:ok, {module, state, pid}},
          else: {:error, :owner_unavailable}

      _ ->
        {:error, :owner_unavailable}
    end
  end

  defp ensure_living(state), do: if(Unit.living?(state), do: :ok, else: {:error, :target_dead})

  defp request_displacement(_pid, {x, y, _map_name}, {x, y}), do: {:ok, {x, y}}

  defp request_displacement(pid, {x, y, map_name}, {dst_x, dst_y}) do
    GenServer.cast(pid, {:movement, {:displace, x, y, map_name, dst_x, dst_y}})
    {:ok, {dst_x, dst_y}}
  end

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0

  defp blow_path(_map_name, x, y, 0, 0, _distance), do: {x, y}
  defp blow_path(_map_name, x, y, _dx, _dy, 0), do: {x, y}

  defp blow_path(map_name, x, y, dx, dy, distance) do
    Enum.reduce_while(1..distance, {x, y}, fn _step, {cx, cy} ->
      next = {cx + dx, cy + dy}

      if Cell.step_traversable?(map_name, {cx, cy}, next) do
        {:cont, next}
      else
        {:halt, {cx, cy}}
      end
    end)
  end

  defp pull_path(_map_data, position, position), do: position

  defp pull_path(map_data, position, target) do
    case Pathfinding.find_path(map_data, position, target) do
      {:ok, [_ | _] = path} -> List.last(path)
      {:error, _reason} -> position
    end
  end
end
