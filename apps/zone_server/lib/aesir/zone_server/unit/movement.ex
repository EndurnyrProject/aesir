defmodule Aesir.ZoneServer.Unit.Movement do
  @moduledoc """
  Single mutation choke point for unit position changes (design Part 3).

  Every stepper, AI path, and interrupt routes a position change through
  `set_position/4`, which updates the spatial index and the unit registry and
  then records the unit in a per-map dirty set. The per-map delta-snapshot
  broadcaster (a later task) drains that set so "what moved" is always
  `O(actually-moved)` rather than `O(population)`.

  The dirty set lives in the `:movement_dirty` ETS table keyed by
  `{map_name, unit_type, unit_id}` with the unit's `move_state` (`0` standing,
  `1` moving) as the value, so the latest mark for a unit wins.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.SpawnView, as: HomunculusSpawnView
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type unit_type :: Unit.unit_type()
  @type unit_id :: integer()
  @type move_state :: 0 | 1

  @standing 0
  @moving 1

  @doc """
  Applies a position change for a unit through the single choke point.

  Updates the spatial index and the unit registry with `updated_state`, then
  marks the unit dirty for its map. The `move_state` is derived from
  `updated_state.movement_state` (`:moving` -> moving, anything else ->
  standing).
  """
  @spec set_position(unit_type(), unit_id(), map(), String.t()) :: :ok
  def set_position(unit_type, unit_id, updated_state, map_name) do
    previous = SpatialIndex.get_unit_position(unit_type, unit_id)

    SpatialIndex.update_unit_position(
      unit_type,
      unit_id,
      updated_state.x,
      updated_state.y,
      map_name
    )

    UnitRegistry.update_unit_state(unit_type, unit_id, updated_state)
    notify_homunculus_boundaries(unit_type, unit_id, previous, updated_state, map_name)
    mark_dirty(map_name, unit_type, unit_id, move_state(updated_state.movement_state))

    mover = {unit_type, unit_id}
    fire_on_leave(mover, previous, map_name, updated_state.x, updated_state.y)
    Trigger.on_enter_cell(mover, map_name, updated_state.x, updated_state.y)
    fire_movement_contact(mover, previous, map_name, updated_state.x, updated_state.y)
  end

  @spec fire_on_leave(
          {atom(), unit_id()},
          {:ok, {integer(), integer(), String.t()}} | {:error, term()},
          String.t(),
          integer(),
          integer()
        ) :: :ok
  defp fire_on_leave(mover, {:ok, {old_x, old_y, old_map}}, new_map, new_x, new_y)
       when old_map != new_map or old_x != new_x or old_y != new_y do
    Trigger.on_leave_cell(mover, old_map, old_x, old_y, new_map, new_x, new_y)
  end

  defp fire_on_leave(_mover, _previous, _new_map, _new_x, _new_y), do: :ok

  defp fire_movement_contact(
         {unit_type, unit_id} = mover,
         {:ok, {old_x, old_y, old_map}},
         map_name,
         x,
         y
       )
       when old_map != map_name or old_x != x or old_y != y do
    unless inactive_player?(mover) do
      map_name
      |> SpatialIndex.get_all_units_in_range(x, y, 1)
      |> Enum.reject(&(&1 == mover or inactive_player?(&1)))
      |> Enum.each(fn contact = {contact_type, contact_id} ->
        StatusInterpreter.on_movement_contact(unit_type, unit_id, contact)
        StatusInterpreter.on_movement_contact(contact_type, contact_id, mover)
      end)
    end

    :ok
  end

  defp fire_movement_contact(_mover, _previous, _map_name, _x, _y), do: :ok

  defp inactive_player?({:player, player_id}) do
    case UnitRegistry.get_unit(:player, player_id) do
      {:ok, {_module, player, _pid}} -> not Unit.living?(player)
      {:error, :not_found} -> true
    end
  end

  defp inactive_player?(_unit), do: false

  @doc """
  Records a unit in its map's dirty set with the given `move_state`.

  Re-marking the same unit overwrites the previous entry, so only the most
  recent `move_state` survives until the next drain.
  """
  @spec mark_dirty(String.t(), unit_type(), unit_id(), move_state()) :: :ok
  def mark_dirty(map_name, unit_type, unit_id, move_state) do
    :ets.insert(dirty_table(), {{map_name, unit_type, unit_id}, move_state})
    :ok
  end

  @doc "Removes a unit from its map's pending movement snapshot."
  @spec clear_dirty(String.t(), unit_type(), unit_id()) :: :ok
  def clear_dirty(map_name, unit_type, unit_id) do
    :ets.delete(dirty_table(), {map_name, unit_type, unit_id})
    :ok
  end

  @doc """
  Drains and clears the dirty set for a map.

  Returns `[{unit_type, unit_id, move_state}]` for the units marked on that map
  and deletes the drained rows, so a subsequent call returns `[]` until new
  marks arrive. Units marked on other maps are untouched.
  """
  @spec drain_dirty(String.t()) :: [{unit_type(), unit_id(), move_state()}]
  def drain_dirty(map_name) do
    match_spec = [
      {
        {{map_name, :"$1", :"$2"}, :"$3"},
        [],
        [{{:"$1", :"$2", :"$3"}}]
      }
    ]

    drained = :ets.select(dirty_table(), match_spec)

    Enum.each(drained, fn {unit_type, unit_id, _move_state} ->
      :ets.delete(dirty_table(), {map_name, unit_type, unit_id})
    end)

    drained
  end

  defp notify_homunculus_boundaries(
         :homunculus,
         gid,
         previous,
         updated_state,
         map_name
       ) do
    old_players = players_near(previous)

    new_players =
      MapSet.new(
        SpatialIndex.get_players_in_range(
          map_name,
          updated_state.x,
          updated_state.y,
          Config.view_range()
        )
      )

    old_players
    |> MapSet.difference(new_players)
    |> HomunculusSpawnView.notify_left(gid)

    new_players
    |> MapSet.difference(old_players)
    |> HomunculusSpawnView.notify_entered(gid)
  end

  defp notify_homunculus_boundaries(_type, _id, _previous, _state, _map), do: :ok

  defp players_near({:ok, {x, y, map_name}}) do
    map_name
    |> SpatialIndex.get_players_in_range(x, y, Config.view_range())
    |> MapSet.new()
  end

  defp players_near({:error, _reason}), do: MapSet.new()

  @spec move_state(atom()) :: move_state()
  defp move_state(:moving), do: @moving
  defp move_state(_), do: @standing

  defp dirty_table, do: table_for(:movement_dirty)
end
