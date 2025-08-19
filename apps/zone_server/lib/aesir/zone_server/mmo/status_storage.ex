defmodule Aesir.ZoneServer.Mmo.StatusStorage do
  @moduledoc """
  ETS-based storage for player status changes.
  Provides fast concurrent access to status data without GenServer bottlenecks.
  """

  @table_name :player_statuses

  @doc """
  Initializes the ETS table for status storage.
  Should be called during application startup.
  """
  @spec init() :: :ok
  def init do
    case :ets.whereis(@table_name) do
      :undefined ->
        # Create table with read concurrency optimization
        # Key: {player_id, status_type}
        # Value: StatusEntry struct
        :ets.new(@table_name, [
          :set,
          :public,
          :named_table,
          {:read_concurrency, true},
          {:write_concurrency, true}
        ])

        :ok

      _tid ->
        # Table already exists
        :ok
    end
  end

  @doc """
  Applies a status change to a player.
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
    # Create status instance as a plain map
    entry = %{
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
      tick_count: 0
    }

    # Calculate expiration time based on duration or tick
    actual_duration = duration || tick

    entry =
      if actual_duration > 0 do
        expires_at = System.monotonic_time(:millisecond) + actual_duration
        Map.put(entry, :expires_at, expires_at)
      else
        Map.put(entry, :expires_at, nil)
      end

    :ets.insert(@table_name, {{player_id, status_type}, entry})
    :ok
  end

  @doc """
  Removes a status from a player.
  """
  @spec remove_status(integer(), atom()) :: :ok
  def remove_status(player_id, status_type) do
    :ets.delete(@table_name, {player_id, status_type})
    :ok
  end

  @doc """
  Gets a specific status for a player.
  """
  @spec get_status(integer(), atom()) :: map() | nil
  def get_status(player_id, status_type) do
    case :ets.lookup(@table_name, {player_id, status_type}) do
      [{{^player_id, ^status_type}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Gets all active statuses for a player.
  """
  @spec get_player_statuses(integer()) :: list(map())
  def get_player_statuses(player_id) do
    :ets.match_object(@table_name, {{player_id, :_}, :_})
    |> Enum.map(fn {_key, entry} -> entry end)
  end

  @doc """
  Checks if a player has a specific status.
  """
  @spec has_status?(integer(), atom()) :: boolean()
  def has_status?(player_id, status_type) do
    :ets.member(@table_name, {player_id, status_type})
  end

  @doc """
  Clears all statuses for a player.
  """
  @spec clear_player_statuses(integer()) :: :ok
  def clear_player_statuses(player_id) do
    keys =
      :ets.match(@table_name, {{player_id, :"$1"}, :_})
      |> Enum.map(fn [status_type] -> {player_id, status_type} end)

    Enum.each(keys, &:ets.delete(@table_name, &1))
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
      :ets.delete(@table_name, {player_id, entry.type})
    end)

    :ok
  end

  @doc """
  Gets all expired statuses (for tick manager).
  Returns list of {{player_id, status_type}, entry} tuples.
  """
  @spec get_expired_statuses(integer()) :: list({{integer(), atom()}, map()})
  def get_expired_statuses(now_ms) do
    # Match spec to find all entries where expires_at <= now_ms
    match_spec = [
      {
        {:"$1", :"$2"},
        [{:"=<", {:map_get, :expires_at, :"$2"}, now_ms}],
        [{{:"$1", :"$2"}}]
      }
    ]

    :ets.select(@table_name, match_spec)
  end

  @doc """
  Gets all statuses that need tick processing.
  This will be filtered by status type in the tick manager.
  """
  @spec get_all_statuses() :: list({{integer(), atom()}, map()})
  def get_all_statuses do
    :ets.tab2list(@table_name)
  end

  @doc """
  Updates a status entry in place.
  """
  @spec update_status(integer(), atom(), (map() -> map())) :: :ok
  def update_status(player_id, status_type, update_fn) do
    case get_status(player_id, status_type) do
      nil ->
        :ok

      entry ->
        updated = update_fn.(entry)
        :ets.insert(@table_name, {{player_id, status_type}, updated})
        :ok
    end
  end

  @doc """
  Gets statuses for multiple players (useful for area effects).
  """
  @spec get_area_statuses(list(integer())) :: %{integer() => list(map())}
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
    :ets.info(@table_name, :size) || 0
  end

  @doc """
  Count active statuses for a specific player.
  """
  @spec count_player_statuses(integer()) :: non_neg_integer()
  def count_player_statuses(player_id) do
    :ets.match(@table_name, {{player_id, :_}, :_})
    |> length()
  end

  @doc """
  Debug function to inspect all statuses.
  """
  @spec dump_all() :: list()
  def dump_all do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {{player_id, status_type}, entry} ->
      %{
        player_id: player_id,
        status: status_type,
        entry: entry
      }
    end)
  end
end
