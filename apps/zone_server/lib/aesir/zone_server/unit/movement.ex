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

  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Unit
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
    SpatialIndex.update_unit_position(
      unit_type,
      unit_id,
      updated_state.x,
      updated_state.y,
      map_name
    )

    UnitRegistry.update_unit_state(unit_type, unit_id, updated_state)
    mark_dirty(map_name, unit_type, unit_id, move_state(updated_state.movement_state))

    Trigger.on_enter_cell({unit_type, unit_id}, map_name, updated_state.x, updated_state.y)
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

  @spec move_state(atom()) :: move_state()
  defp move_state(:moving), do: @moving
  defp move_state(_), do: @standing

  defp dirty_table, do: table_for(:movement_dirty)
end
