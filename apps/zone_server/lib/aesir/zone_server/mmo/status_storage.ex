defmodule Aesir.ZoneServer.Mmo.StatusStorage do
  @moduledoc """
  ETS-based storage for unit status changes.
  Provides fast concurrent access to status data without GenServer bottlenecks.

  This module handles the persistent storage of status effects applied to all game entities
  (players, mobs, NPCs, pets, etc.). It uses ETS tables for high-performance concurrent access
  without GenServer bottlenecks.

  The storage system is optimized for:
  1. Fast lookups by unit_type, unit_id, and status_type
  2. Efficient retrieval of statuses due for tick processing
  3. Selective updates to minimize memory churn
  4. Support for multiple unit types with polymorphic access
  """
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit

  @type unit_type :: Unit.unit_type()

  @doc """
  Applies a status change to a unit.

  Creates a new status effect entry and stores it in the ETS table.
  If a status with the same type already exists for the unit, it will be replaced.

  A status with no tick interval (`tick <= 0`) gets a `nil` next_tick_at and is
  never picked up by `get_due_statuses/1`; only statuses with periodic behavior
  enter the tick loop.

  ## Parameters
  - unit_type: Type of unit (:player, :mob, :npc, etc.)
  - unit_id: The ID of the unit receiving the status
  - status_type: The type of status effect to apply (atom)
  - status_params: Keyword list containing status parameters

  ## Returns
  :ok
  """
  @spec apply_status(unit_type(), integer(), atom(), StatusEntry.status_params()) :: :ok
  def apply_status(unit_type, unit_id, status_type, status_params \\ []) do
    apply_status_with_entry(unit_type, unit_id, status_type, status_params)
    :ok
  end

  @doc """
  Applies a status and reports whether its exact entry became current.

  Successful inserts return `{:stored, entry, nil}`. Successful replacements
  return `{:stored, entry, prior_entry}`, where `prior_entry` is the exact entry
  replaced by the successful compare-and-swap. A concurrent newer same-type
  application wins even when this call reaches storage later. Callers that
  perform generation-sensitive lifecycle work must retain the returned entry
  instead of fetching by status type after insertion.

  `decide` is asked about the current entry (nil when there is none) inside the
  compare-and-swap: `:store` stores the entry, `{:store, adjust}` stores
  `adjust.(entry)`, and `:keep` leaves the current entry and returns
  `{:kept, current}`.
  """
  @spec apply_status_with_entry(
          unit_type(),
          integer(),
          atom(),
          StatusEntry.status_params(),
          decision()
        ) ::
          {:stored, StatusEntry.t(), StatusEntry.t() | nil}
          | {:superseded | :kept, StatusEntry.t()}
  def apply_status_with_entry(
        unit_type,
        unit_id,
        status_type,
        status_params \\ [],
        decide \\ &store_always/1
      ) do
    entry = build_entry(unit_type, unit_id, status_type, status_params)
    store_if_newer(unit_type, unit_id, entry, decide)
  end

  @typedoc "How a new entry meets the current one inside the compare-and-swap."
  @type decision ::
          (StatusEntry.t() | nil ->
             :store | {:store, (StatusEntry.t() -> StatusEntry.t())} | :keep)

  defp store_always(_current), do: :store

  @doc """
  Atomically stores an entry only when its generation is newer than the current entry.

  Entries with a nil generation are older than generated entries. Successful
  inserts return a nil prior entry; successful replacements return the exact
  entry replaced by their compare-and-swap. Superseded results continue to
  report the current entry.
  """
  @spec store_if_newer(unit_type(), integer(), StatusEntry.t(), decision()) ::
          {:stored, StatusEntry.t(), StatusEntry.t() | nil}
          | {:superseded | :kept, StatusEntry.t()}
  def store_if_newer(
        unit_type,
        unit_id,
        %StatusEntry{type: status_type} = entry,
        decide \\ &store_always/1
      ) do
    table = table_for(:player_statuses)
    key = {unit_type, unit_id, status_type}
    store_if_newer_loop(table, key, entry, decide)
  end

  defp store_if_newer_loop(table, key, entry, decide) do
    case :ets.lookup(table, key) do
      [] ->
        stored = decided_entry(decide.(nil), entry)

        if :ets.insert_new(table, {key, stored}) do
          {:stored, stored, nil}
        else
          store_if_newer_loop(table, key, entry, decide)
        end

      [{^key, current}] ->
        if newer_generation?(entry.generation, current.generation),
          do: replace_if_current(table, key, current, entry, decide),
          else: {:superseded, current}
    end
  end

  defp replace_if_current(table, key, current, entry, decide) do
    case decide.(current) do
      :keep ->
        {:kept, current}

      decision ->
        stored = decided_entry(decision, entry)

        match_spec = [
          {{key, :"$1"}, [{:"=:=", :"$1", {:const, current}}], [{:const, {key, stored}}]}
        ]

        if :ets.select_replace(table, match_spec) == 1,
          do: {:stored, stored, current},
          else: store_if_newer_loop(table, key, entry, decide)
    end
  end

  defp decided_entry(:store, entry), do: entry
  defp decided_entry({:store, adjust}, entry), do: adjust.(entry)

  defp newer_generation?(generation, nil) when is_integer(generation) and generation > 0,
    do: true

  defp newer_generation?(generation, current_generation)
       when is_integer(generation) and generation > 0 and is_integer(current_generation) and
              current_generation > 0,
       do: generation > current_generation

  defp newer_generation?(nil, nil), do: false
  defp newer_generation?(nil, current_generation) when is_integer(current_generation), do: false

  defp build_entry(unit_type, unit_id, status_type, status_params) do
    {val1, val2, val3, val4, tick, flag, caster_id, duration, state, phase} =
      StatusEntry.extract_params(status_params)

    now_ms = System.monotonic_time(:millisecond)

    %StatusEntry{
      type: status_type,
      val1: val1,
      val2: val2,
      val3: val3,
      val4: val4,
      tick: tick,
      flag: flag,
      source_id: caster_id || unit_id,
      source_type: StatusEntry.resolve_source_type(unit_type, unit_id, caster_id, status_params),
      state: state,
      phase: phase,
      started_at: now_ms,
      expires_at: if(duration && duration > 0, do: now_ms + duration, else: nil),
      next_tick_at: if(tick > 0, do: now_ms + tick, else: nil),
      tick_count: 0,
      generation: System.unique_integer([:monotonic, :positive])
    }
  end

  @doc """
  Removes a status from a unit.
  """
  @spec remove_status(unit_type(), integer(), atom()) :: :ok
  def remove_status(unit_type, unit_id, status_type) do
    :ets.delete(table_for(:player_statuses), {unit_type, unit_id, status_type})
    :ok
  end

  @doc """
  Atomically removes a status only when its current entry exactly matches the expected entry.

  Returns whether the expected entry was deleted. A newer same-type application
  is never removed.
  """
  @spec remove_status_if_current(unit_type(), integer(), atom(), StatusEntry.t()) :: boolean()
  def remove_status_if_current(unit_type, unit_id, status_type, expected_entry) do
    key = {unit_type, unit_id, status_type}

    match_spec = [
      {{key, :"$1"}, [{:"=:=", :"$1", {:const, expected_entry}}], [true]}
    ]

    :ets.select_delete(table_for(:player_statuses), match_spec) == 1
  end

  @doc """
  Atomically replaces a status only when its current entry exactly matches the expected entry.

  Returns whether the replacement was stored. A newer same-type application is
  never overwritten.
  """
  @spec replace_status_if_current(
          unit_type(),
          integer(),
          atom(),
          StatusEntry.t(),
          StatusEntry.t()
        ) :: boolean()
  def replace_status_if_current(unit_type, unit_id, status_type, expected_entry, replacement) do
    key = {unit_type, unit_id, status_type}

    match_spec = [
      {{key, :"$1"}, [{:"=:=", :"$1", {:const, expected_entry}}],
       [
         {:const, {key, replacement}}
       ]}
    ]

    :ets.select_replace(table_for(:player_statuses), match_spec) == 1
  end

  @doc """
  Atomically removes and returns a status entry.

  Consumers of single-use statuses use this to claim the entry before applying
  their effect, so concurrent combat paths cannot consume it twice.
  """
  @spec take_status(unit_type(), integer(), atom()) :: StatusEntry.t() | nil
  def take_status(unit_type, unit_id, status_type) do
    case :ets.take(table_for(:player_statuses), {unit_type, unit_id, status_type}) do
      [{{^unit_type, ^unit_id, ^status_type}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Gets a specific status for a unit.

  ## Parameters
  - unit_type: Type of unit
  - unit_id: The ID of the unit
  - status_type: The type of status to get

  ## Returns
  StatusEntry struct or nil if not found
  """
  @spec get_status(unit_type(), integer(), atom()) :: StatusEntry.t() | nil
  def get_status(unit_type, unit_id, status_type) do
    case :ets.lookup(table_for(:player_statuses), {unit_type, unit_id, status_type}) do
      [{{^unit_type, ^unit_id, ^status_type}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Gets all active statuses for a unit.

  ## Parameters
  - unit_type: Type of unit
  - unit_id: The ID of the unit

  ## Returns
  List of StatusEntry structs
  """
  @spec get_unit_statuses(unit_type(), integer()) :: list(StatusEntry.t())
  def get_unit_statuses(unit_type, unit_id) do
    :ets.match_object(table_for(:player_statuses), {{unit_type, unit_id, :_}, :_})
    |> Enum.map(fn {_key, entry} -> entry end)
  end

  @doc """
  Checks if a unit has a specific status.
  """
  @spec has_status?(unit_type(), integer(), atom()) :: boolean()
  def has_status?(unit_type, unit_id, status_type) do
    :ets.member(table_for(:player_statuses), {unit_type, unit_id, status_type})
  end

  @doc """
  Clears all statuses for a unit, and its status-data counters.
  """
  @spec clear_unit_statuses(unit_type(), integer()) :: :ok
  def clear_unit_statuses(unit_type, unit_id) do
    keys =
      :ets.match(table_for(:player_statuses), {{unit_type, unit_id, :"$1"}, :_})
      |> Enum.map(fn [status_type] -> {unit_type, unit_id, status_type} end)

    Enum.each(keys, &:ets.delete(table_for(:player_statuses), &1))
    reset_storm_gust_counter(unit_type, unit_id)
    :ets.delete(table_for(:status_counters), {unit_type, unit_id, :last_effect})
    :ok
  end

  @doc """
  Gets every stored status as `{{unit_type, unit_id, status_type}, entry}` tuples.
  """
  @spec get_all_statuses() :: list({{unit_type(), integer(), atom()}, StatusEntry.t()})
  def get_all_statuses do
    :ets.tab2list(table_for(:player_statuses))
  end

  @doc """
  Gets all expired statuses (for tick manager).
  Returns list of {{unit_type, unit_id, status_type}, entry} tuples.

  ## Parameters
  - now_ms: Current time in milliseconds

  ## Returns
  List of {{unit_type, unit_id, status_type}, StatusEntry} tuples for all expired statuses
  """
  @spec get_expired_statuses(integer()) ::
          list({{unit_type(), integer(), atom()}, StatusEntry.t()})
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
  Gets all statuses that are due for a tick update at the given time.
  Returns list of {{unit_type, unit_id, status_type}, entry} tuples.
  Only returns statuses that actually need processing, significantly reducing
  the number of statuses processed each tick.

  ## Parameters
  - now_ms: Current time in milliseconds

  ## Returns
  List of {{unit_type, unit_id, status_type}, StatusEntry} tuples for statuses due for processing
  """
  @spec get_due_statuses(integer()) :: list({{unit_type(), integer(), atom()}, StatusEntry.t()})
  def get_due_statuses(now_ms) do
    # Match spec to find all entries where next_tick_at <= now_ms. A nil
    # next_tick_at (tickless status) compares greater than any integer in
    # Erlang term order, so those entries never match.
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
  - unit_type: Type of unit
  - unit_id: The ID of the unit
  - status_type: The type of status to update
  - update_fn: Function that receives the current StatusEntry and returns an updated one

  ## Returns
  :ok
  """
  @spec update_status(unit_type(), integer(), atom(), (StatusEntry.t() -> StatusEntry.t())) :: :ok
  def update_status(unit_type, unit_id, status_type, update_fn) do
    case get_status(unit_type, unit_id, status_type) do
      nil ->
        :ok

      entry ->
        updated = update_fn.(entry)
        :ets.insert(table_for(:player_statuses), {{unit_type, unit_id, status_type}, updated})
        :ok
    end
  end

  @doc """
  Updates only the next_tick_at field of a status entry.

  The entry is stored as a single struct in element 2 of the ETS tuple, so the
  update is a read-modify-write of the whole struct. If the status no longer
  exists the update is a no-op.
  """
  @spec update_next_tick(unit_type(), integer(), atom(), integer()) :: :ok
  def update_next_tick(unit_type, unit_id, status_type, next_tick_at) do
    update_status(unit_type, unit_id, status_type, fn entry ->
      %{entry | next_tick_at: next_tick_at}
    end)
  end

  @doc """
  Count total active statuses in the system.
  """
  @spec count_all_statuses() :: non_neg_integer()
  def count_all_statuses do
    :ets.info(table_for(:player_statuses), :size) || 0
  end

  @doc """
  Count active statuses for a specific unit.
  """
  @spec count_unit_statuses(unit_type(), integer()) :: non_neg_integer()
  def count_unit_statuses(unit_type, unit_id) do
    :ets.match(table_for(:player_statuses), {{unit_type, unit_id, :_}, :_})
    |> length()
  end

  @doc """
  Counts one classic Storm Gust hit on a unit and returns the new count.

  The counter belongs to the unit's status data, not to one field, so hits from
  different Storm Gusts add up. It is a byte: it wraps from 255 to 0. Only the
  skill-unit manager increments it; death, removal and the buff-clearing
  effects reset it.
  """
  @spec increment_storm_gust_counter(unit_type(), integer()) :: non_neg_integer()
  def increment_storm_gust_counter(unit_type, unit_id) do
    key = {unit_type, unit_id, :storm_gust}
    :ets.update_counter(table_for(:status_counters), key, {2, 1, 255, 0}, {key, 0})
  end

  @doc "Returns a unit's classic Storm Gust hit count (0 when it has none)."
  @spec storm_gust_counter(unit_type(), integer()) :: non_neg_integer()
  def storm_gust_counter(unit_type, unit_id) do
    case :ets.lookup(table_for(:status_counters), {unit_type, unit_id, :storm_gust}) do
      [{_key, count}] -> count
      [] -> 0
    end
  end

  @last_effect_ms 10

  @doc """
  Records `status_id` as the status damage last broke on a unit holding a body
  state, for 10 ms from `now_ms`, so the same attack cannot start a status whose
  Fail list names it. A record still lasting is kept, not replaced.
  """
  @spec note_last_effect(unit_type(), integer(), atom(), integer()) :: :ok
  def note_last_effect(unit_type, unit_id, status_id, now_ms) do
    if is_nil(last_effect(unit_type, unit_id, now_ms)) do
      :ets.insert(
        table_for(:status_counters),
        {{unit_type, unit_id, :last_effect}, status_id, now_ms + @last_effect_ms}
      )
    end

    :ok
  end

  @doc "Returns the status damage last broke on a unit while its record lasts, else nil."
  @spec last_effect(unit_type(), integer(), integer()) :: atom() | nil
  def last_effect(unit_type, unit_id, now_ms) do
    case :ets.lookup(table_for(:status_counters), {unit_type, unit_id, :last_effect}) do
      [{_key, status_id, until}] when now_ms < until -> status_id
      _none -> nil
    end
  end

  @doc "Resets a unit's classic Storm Gust hit count to 0."
  @spec reset_storm_gust_counter(unit_type(), integer()) :: :ok
  def reset_storm_gust_counter(unit_type, unit_id) do
    :ets.delete(table_for(:status_counters), {unit_type, unit_id, :storm_gust})
    :ok
  end
end
