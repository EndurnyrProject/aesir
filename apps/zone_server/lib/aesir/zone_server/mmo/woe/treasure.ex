defmodule Aesir.ZoneServer.Mmo.Woe.Treasure do
  @moduledoc """
  Plans and summons the daily treasure boxes for owned WoE castles.

  Box count scales with a castle's economy level, from 4 boxes at economy 0
  up to all 24 cells at economy 100. Each cell alternates between the
  castle's two treasure mob ids. Live boxes are tracked per castle/slot in
  ETS so a slot is never double-filled across daily spawns, and frees again
  once its box dies or is otherwise terminated.
  """

  require Logger

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore

  @min_boxes 4
  @max_boxes 24

  @typedoc "One planned treasure box: its slot, mob id, and spawn cell."
  @type planned_box ::
          {slot :: non_neg_integer(), box_id :: pos_integer(), x :: pos_integer(),
           y :: pos_integer()}

  @doc """
  Plans the treasure boxes still missing for `castle` at `economy`.

  Box count is `min(div(economy, 5) + 4, 24)`. Slot `i` uses cell `i` and
  alternates between the castle's two box ids (`box_id + rem(i, 2)`). Slots
  already in `live_slots`, and slots at or past the count, are omitted.
  """
  @spec plan(Castle.t(), 0..100, [non_neg_integer()]) :: [planned_box()]
  def plan(%Castle{treasure: %{box_id: box_id, cells: cells}}, economy, live_slots) do
    count = min(div(economy, 5) + @min_boxes, @max_boxes)

    for slot <- 0..(count - 1), slot not in live_slots do
      {x, y} = Enum.at(cells, slot)
      {slot, box_id + rem(slot, 2), x, y}
    end
  end

  @doc """
  Summons `castle`'s missing treasure boxes for the day and records each
  live unit id in its slot.

  A slot whose summon fails (including a map with no running coordinator)
  logs a warning and is left empty for a later attempt.
  """
  @spec spawn_daily(Castle.t()) :: :ok
  def spawn_daily(%Castle{id: castle_id, map: map} = castle) do
    economy = CastleStore.economy(castle_id).economy

    castle
    |> plan(economy, live_slots(castle_id))
    |> Enum.each(fn {slot, mob_id, x, y} -> summon_slot(castle_id, map, slot, mob_id, x, y) end)

    :ok
  end

  @doc """
  Summons the day's treasure boxes for every owned castle.
  """
  @spec spawn_all() :: :ok
  def spawn_all do
    Enum.each(CastleDb.all(), fn castle ->
      case CastleStore.owner(castle.id) do
        nil -> :ok
        _guild_id -> spawn_daily(castle)
      end
    end)
  end

  @doc """
  Frees the slot held by `unit_id`, if any.
  """
  @spec release(non_neg_integer()) :: :ok
  def release(unit_id) do
    :ets.match_delete(table_for(:castle_treasure), {:_, unit_id})
    :ok
  end

  @doc """
  Live treasure box slots currently filled for `castle_id`.
  """
  @spec live_slots(non_neg_integer()) :: [non_neg_integer()]
  def live_slots(castle_id) do
    :ets.select(table_for(:castle_treasure), [{{{castle_id, :"$1"}, :_}, [], [:"$1"]}])
  end

  @spec summon_slot(
          non_neg_integer(),
          String.t(),
          non_neg_integer(),
          pos_integer(),
          pos_integer(),
          pos_integer()
        ) ::
          :ok
  defp summon_slot(castle_id, map, slot, mob_id, x, y) do
    case Coordinator.summon_mob(map, mob_id, x, y, []) do
      {:ok, unit_id} ->
        :ets.insert(table_for(:castle_treasure), {{castle_id, slot}, unit_id})
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to summon treasure box for castle #{castle_id} slot #{slot} on #{map}: #{inspect(reason)}"
        )

        :ok
    end
  end
end
