defmodule Aesir.ZoneServer.Mmo.StatusStorage do
  @moduledoc """
  ETS-based storage for player status changes.
  Provides fast concurrent access to status data without GenServer bottlenecks.

  This module handles the persistent storage of status effects applied to game entities.
  It uses ETS tables for high-performance concurrent access without GenServer bottlenecks.

  The storage system is optimized for:
  1. Fast lookups by player_id and status_type
  2. Efficient retrieval of statuses due for tick processing
  3. Selective updates to minimize memory churn
  """
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @doc """
  Applies a status change to a player.

  Creates a new status effect entry and stores it in the ETS table.
  If a status with the same type already exists for the player, it will be replaced.

  ## Parameters
  - player_id: The ID of the player receiving the status
  - status_type: The type of status effect to apply (atom)
  - val1-val4: Status-specific values
  - tick: Tick interval in ms
  - flag: Status flags
  - duration: Duration in ms (nil for permanent)
  - source_id: Entity that applied the status
  - state: Custom state data
  - phase: Current phase

  ## Returns
  :ok
  """
  @spec apply_status(
          integer(),
          atom(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer() | nil,
          integer() | nil,
          map() | nil,
          atom() | nil
        ) :: :ok
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def apply_status(
        player_id,
        status_type,
        val1,
        val2,
        val3,
        val4,
        tick,
        flag,
        duration \\ nil,
        source_id \\ nil,
        state \\ %{},
        phase \\ nil
      ) do
    # Create status instance as a struct
    now_ms = System.monotonic_time(:millisecond)
    tick_interval = if tick > 0, do: tick, else: 1000

    # Calculate expiration time
    expires_at =
      if duration && duration > 0 do
        now_ms + duration
      else
        nil
      end

    # Create the status entry directly
    entry = %StatusEntry{
      type: status_type,
      val1: val1,
      val2: val2,
      val3: val3,
      val4: val4,
      tick: tick,
      flag: flag,
      source_id: source_id || player_id,
      state: state || %{},
      phase: phase,
      started_at: System.system_time(:millisecond),
      expires_at: expires_at,
      next_tick_at: now_ms + tick_interval,
      tick_count: 0
    }

    :ets.insert(table_for(:player_statuses), {{player_id, status_type}, entry})
    :ok
  end

  @doc """
  Removes a status from a player.
  """
  @spec remove_status(integer(), atom()) :: :ok
  def remove_status(player_id, status_type) do
    :ets.delete(table_for(:player_statuses), {player_id, status_type})
    :ok
  end

  @doc """
  Gets a specific status for a player.

  ## Parameters
  - player_id: The ID of the player
  - status_type: The type of status to get

  ## Returns
  StatusEntry struct or nil if not found
  """
  @spec get_status(integer(), atom()) :: StatusEntry.t() | nil
  def get_status(player_id, status_type) do
    case :ets.lookup(table_for(:player_statuses), {player_id, status_type}) do
      [{{^player_id, ^status_type}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Gets all active statuses for a player.

  ## Parameters
  - player_id: The ID of the player

  ## Returns
  List of StatusEntry structs
  """
  @spec get_player_statuses(integer()) :: list(StatusEntry.t())
  def get_player_statuses(player_id) do
    :ets.match_object(table_for(:player_statuses), {{player_id, :_}, :_})
    |> Enum.map(fn {_key, entry} -> entry end)
  end

  @doc """
  Checks if a player has a specific status.
  """
  @spec has_status?(integer(), atom()) :: boolean()
  def has_status?(player_id, status_type) do
    :ets.member(table_for(:player_statuses), {player_id, status_type})
  end

  @doc """
  Clears all statuses for a player.
  """
  @spec clear_player_statuses(integer()) :: :ok
  def clear_player_statuses(player_id) do
    keys =
      :ets.match(table_for(:player_statuses), {{player_id, :"$1"}, :_})
      |> Enum.map(fn [status_type] -> {player_id, status_type} end)

    Enum.each(keys, &:ets.delete(table_for(:player_statuses), &1))
    :ok
  end

  @doc """
  Clears specific types of statuses for a player (buffs/debuffs).
  This function now requires the Interpreter to be loaded to check properties.
  """
  @spec clear_status_types(integer(), :buffs | :debuffs | :all) :: :ok
  def clear_status_types(player_id, type) do
    alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter

    statuses = get_player_statuses(player_id)

    to_remove =
      case type do
        :all ->
          statuses

        :buffs ->
          Enum.filter(statuses, fn status ->
            Interpreter.buff?(status.type)
          end)

        :debuffs ->
          Enum.filter(statuses, fn status ->
            Interpreter.debuff?(status.type)
          end)
      end

    Enum.each(to_remove, fn entry ->
      :ets.delete(table_for(:player_statuses), {player_id, entry.type})
    end)

    :ok
  end

  @doc """
  Gets all expired statuses (for tick manager).
  Returns list of {{player_id, status_type}, entry} tuples.

  ## Parameters
  - now_ms: Current time in milliseconds

  ## Returns
  List of {{player_id, status_type}, StatusEntry} tuples for all expired statuses
  """
  @spec get_expired_statuses(integer()) :: list({{integer(), atom()}, StatusEntry.t()})
  def get_expired_statuses(now_ms) do
    # Match spec to find all entries where expires_at <= now_ms
    match_spec = [
      {
        {:"$1", :"$2"},
        [{:"=<", {:map_get, :expires_at, :"$2"}, now_ms}],
        [{{:"$1", :"$2"}}]
      }
    ]

    :ets.select(table_for(:player_statuses), match_spec)
  end

  @doc """
  Gets all statuses that need tick processing.
  This will be filtered by status type in the tick manager.

  DEPRECATED: Use get_due_statuses/1 instead for better performance.

  ## Returns
  List of {{player_id, status_type}, StatusEntry} tuples for all statuses
  """
  @spec get_all_statuses() :: list({{integer(), atom()}, StatusEntry.t()})
  def get_all_statuses do
    :ets.tab2list(table_for(:player_statuses))
  end

  @doc """
  Gets all statuses that are due for a tick update at the given time.
  Returns list of {{player_id, status_type}, entry} tuples.
  Only returns statuses that actually need processing, significantly reducing
  the number of statuses processed each tick.

  ## Parameters
  - now_ms: Current time in milliseconds

  ## Returns
  List of {{player_id, status_type}, StatusEntry} tuples for statuses due for processing
  """
  @spec get_due_statuses(integer()) :: list({{integer(), atom()}, StatusEntry.t()})
  def get_due_statuses(now_ms) do
    # Match spec to find all entries where next_tick_at <= now_ms
    match_spec = [
      {
        {:"$1", :"$2"},
        [{:"=<", {:map_get, :next_tick_at, :"$2"}, now_ms}],
        [{{:"$1", :"$2"}}]
      }
    ]

    :ets.select(table_for(:player_statuses), match_spec)
  end

  @doc """
  Updates a status entry in place.

  ## Parameters
  - player_id: The ID of the player
  - status_type: The type of status to update
  - update_fn: Function that receives the current StatusEntry and returns an updated one

  ## Returns
  :ok
  """
  @spec update_status(integer(), atom(), (StatusEntry.t() -> StatusEntry.t())) :: :ok
  def update_status(player_id, status_type, update_fn) do
    case get_status(player_id, status_type) do
      nil ->
        :ok

      entry ->
        updated = update_fn.(entry)
        :ets.insert(table_for(:player_statuses), {{player_id, status_type}, updated})
        :ok
    end
  end

  @doc """
  Updates only the next_tick_at field of a status entry.
  This is more efficient than update_status for the common tick case.
  """
  @spec update_next_tick(integer(), atom(), integer()) :: :ok
  def update_next_tick(player_id, status_type, next_tick_at) do
    # Uses :ets.update_element/3 which is more efficient than read-modify-write
    # Updates only the next_tick_at field in the entry map
    key = {player_id, status_type}

    # Element position 2 is the value part of the ETS tuple
    # We update the next_tick_at field inside the map
    :ets.update_element(
      table_for(:player_statuses),
      key,
      {2, {:map_update, :next_tick_at, next_tick_at}}
    )

    :ok
  rescue
    # If the status no longer exists, just ignore
    _ -> :ok
  end

  @doc """
  Gets statuses for multiple players (useful for area effects).

  ## Parameters
  - player_ids: List of player IDs to get statuses for

  ## Returns
  Map of player_id => list of StatusEntry structs
  """
  @spec get_area_statuses(list(integer())) :: %{integer() => list(StatusEntry.t())}
  def get_area_statuses(player_ids) do
    player_ids
    |> Enum.map(fn player_id ->
      {player_id, get_player_statuses(player_id)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Count total active statuses in the system.
  """
  @spec count_all_statuses() :: non_neg_integer()
  def count_all_statuses do
    :ets.info(table_for(:player_statuses), :size) || 0
  end

  @doc """
  Count active statuses for a specific player.
  """
  @spec count_player_statuses(integer()) :: non_neg_integer()
  def count_player_statuses(player_id) do
    :ets.match(table_for(:player_statuses), {{player_id, :_}, :_})
    |> length()
  end

  @doc """
  Debug function to inspect all statuses.
  """
  @spec dump_all() :: list()
  def dump_all do
    :ets.tab2list(table_for(:player_statuses))
    |> Enum.map(fn {{player_id, status_type}, entry} ->
      %{
        player_id: player_id,
        status: status_type,
        entry: entry
      }
    end)
  end
end
