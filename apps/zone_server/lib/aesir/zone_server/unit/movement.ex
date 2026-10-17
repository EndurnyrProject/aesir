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
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.SpawnView, as: HomunculusSpawnView
  alias Aesir.ZoneServer.Unit.Mob.SpawnView, as: MobSpawnView
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

    finish_position_change(
      {unit_type, unit_id, updated_state},
      previous,
      map_name,
      move_state(updated_state.movement_state),
      :step
    )
  end

  @doc """
  Applies a warp: the unit is removed from its map and put back on its new
  cell, even when that is the cell it stood on.

  Instead of a step, it leaves every ground unit on its old cell as a unit
  removed from the map does (`Trigger.on_removed/1`), then appears on the new
  cell (`Trigger.on_appear/4`: no step bookkeeping, Spider Web, traps and
  timer units do not act on the arrival). Index, registry and dirty-set
  updates are those of `set_position/4`. After leaving the ground units, a
  Homunculus vanishes with the teleport reason for every player that saw it
  and appears for every player in view of its new cell; a mob vanishes with
  the teleport reason for the players in view of its old cell.
  """
  @spec warp_position(unit_type(), unit_id(), map(), String.t()) :: :ok
  def warp_position(unit_type, unit_id, updated_state, map_name) do
    :ok = Trigger.on_removed({unit_type, unit_id})
    previous = SpatialIndex.get_unit_position(unit_type, unit_id)
    vanish(unit_type, unit_id, previous)

    SpatialIndex.update_unit_position(
      unit_type,
      unit_id,
      updated_state.x,
      updated_state.y,
      map_name
    )

    UnitRegistry.update_unit_state(unit_type, unit_id, updated_state)

    finish_position_change(
      {unit_type, unit_id, updated_state},
      previous,
      map_name,
      move_state(updated_state.movement_state),
      :warp
    )
  end

  defp vanish(:homunculus, gid, previous) do
    previous
    |> players_near()
    |> HomunculusSpawnView.notify_vanished(gid, DespawnReason.teleport())
  end

  defp vanish(:mob, instance_id, {:ok, position}),
    do: MobSpawnView.notify_teleported(instance_id, position)

  defp vanish(_unit_type, _unit_id, _previous), do: :ok

  defp cell_events(:step, mover, previous, map_name, x, y),
    do: fire_step(mover, previous, map_name, x, y)

  defp cell_events(:warp, mover, _previous, map_name, x, y),
    do: Trigger.on_appear(mover, map_name, x, y)

  # A step onto another cell runs the old and new cells' units as one pass, a
  # unit with no previous position appears there, and staying on the same
  # cell runs nothing.
  @spec fire_step(
          {atom(), unit_id()},
          {:ok, {integer(), integer(), String.t()}} | {:error, term()},
          String.t(),
          integer(),
          integer()
        ) :: :ok
  defp fire_step(mover, {:ok, {old_x, old_y, old_map}}, map_name, x, y)
       when old_map != map_name or old_x != x or old_y != y,
       do: Trigger.on_step(mover, old_map, old_x, old_y, map_name, x, y)

  defp fire_step(_mover, {:ok, _same_cell}, _map_name, _x, _y), do: :ok

  defp fire_step(mover, {:error, _not_placed}, map_name, x, y),
    do: Trigger.on_appear(mover, map_name, x, y)

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

  @doc "Reads a registry snapshot only when its spatial endpoint is current and consistent."
  @spec swap_ready(unit_type(), unit_id()) ::
          {:ok, {module(), map(), pid()}} | {:error, :stale_endpoint}
  def swap_ready(unit_type, unit_id) do
    with {:ok, {module, %{map_name: state_map, x: state_x, y: state_y} = state, pid}} <-
           UnitRegistry.get_unit(unit_type, unit_id),
         true <- is_binary(state_map) and is_integer(state_x) and is_integer(state_y),
         {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         true <- {state_x, state_y, state_map} == {x, y, map_name} do
      {:ok, {module, state, pid}}
    else
      _invalid -> {:error, :stale_endpoint}
    end
  end

  @doc "Swaps two prevalidated same-map endpoints before emitting movement notifications."
  @spec swap_positions(
          {unit_type(), unit_id(), map()},
          {unit_type(), unit_id(), map()},
          String.t()
        ) :: :ok | {:error, :stale_endpoint}
  def swap_positions(
        {first_type, first_id, first_updated} = first,
        {second_type, second_id, second_updated} = second,
        map_name
      ) do
    with {:ok, first_previous} <-
           validate_swap_endpoint(first_type, first_id, second_updated, map_name),
         {:ok, second_previous} <-
           validate_swap_endpoint(second_type, second_id, first_updated, map_name) do
      SpatialIndex.update_unit_position(
        first_type,
        first_id,
        first_updated.x,
        first_updated.y,
        map_name
      )

      SpatialIndex.update_unit_position(
        second_type,
        second_id,
        second_updated.x,
        second_updated.y,
        map_name
      )

      :ok = UnitRegistry.update_unit_state(first_type, first_id, first_updated)
      :ok = UnitRegistry.update_unit_state(second_type, second_id, second_updated)
      finish_position_change(first, first_previous, map_name, @standing, :step)
      finish_position_change(second, second_previous, map_name, @standing, :step)
    end
  end

  defp validate_swap_endpoint(unit_type, unit_id, other_updated, map_name) do
    with {:ok, {_module, state, _pid}} <- swap_ready(unit_type, unit_id),
         true <- state.map_name == map_name,
         true <- {state.x, state.y} == {other_updated.x, other_updated.y} do
      {:ok, {:ok, {state.x, state.y, map_name}}}
    else
      _invalid -> {:error, :stale_endpoint}
    end
  end

  # Everything after the spatial/registry writes: boundary notifications, the
  # dirty mark, the ground-unit cell events and the contact triggers. A warped
  # unit was removed from its map: every observer in view of its new cell sees
  # it appear.
  defp finish_position_change(
         {unit_type, unit_id, updated_state},
         previous,
         map_name,
         move_state,
         kind
       ) do
    seen_from = if kind == :warp, do: {:error, :removed}, else: previous
    notify_homunculus_boundaries(unit_type, unit_id, seen_from, updated_state, map_name)
    mark_dirty(map_name, unit_type, unit_id, move_state)

    mover = {unit_type, unit_id}
    cell_events(kind, mover, previous, map_name, updated_state.x, updated_state.y)
    Trigger.on_caster_moved(mover, map_name, updated_state.x, updated_state.y)
    fire_movement_contact(mover, previous, map_name, updated_state.x, updated_state.y)
  end

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
