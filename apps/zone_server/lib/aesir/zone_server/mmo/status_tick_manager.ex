defmodule Aesir.ZoneServer.Mmo.StatusTickManager do
  @moduledoc """
  Single process that manages all status tick effects and expirations.
  Runs on a fixed interval and batch processes all status updates.

  This manager is optimized to handle thousands of concurrent players by:
  1. Only processing statuses that are actually due for a tick
  2. Using efficient ETS operations for status updates
  3. Batching processing to avoid overloading the system
  4. Tracking performance metrics to monitor efficiency
  """

  use GenServer
  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  # 1 second tick rate
  @tick_interval_ms 1000
  # Process statuses in batches
  @tick_batch_size 100

  defmodule State do
    defstruct [
      :tick_timer,
      tick_count: 0,
      last_tick: 0,
      # Performance metrics
      last_total_statuses: 0,
      last_due_statuses: 0,
      processing_ratio: 0.0
    ]
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec force_tick() :: :ok
  def force_tick do
    GenServer.cast(__MODULE__, :force_tick)
  end

  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @impl true
  def init(_opts) do
    timer_ref = Process.send_after(self(), :tick, @tick_interval_ms)

    state = %State{
      tick_timer: timer_ref,
      last_tick: System.monotonic_time(:millisecond)
    }

    Logger.info("StatusTickManager started with #{@tick_interval_ms}ms interval")
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    now_ms = System.monotonic_time(:millisecond)

    # Process expired statuses
    expired_count = process_expired_statuses(now_ms)

    # Process tick effects
    tick_count = process_tick_effects(now_ms)

    # Get total statuses for stats
    total_statuses = StatusStorage.count_all_statuses()

    # Calculate processing ratio (percentage of statuses actually processed)
    processing_ratio = if total_statuses > 0, do: tick_count / total_statuses * 100, else: 0.0

    # Update state with performance metrics
    new_state = %{
      state
      | tick_count: state.tick_count + 1,
        last_tick: now_ms,
        last_total_statuses: total_statuses,
        last_due_statuses: tick_count,
        processing_ratio: processing_ratio
    }

    # Log stats periodically (every 60 ticks)
    if rem(new_state.tick_count, 60) == 0 do
      Logger.debug(
        "StatusTick ##{new_state.tick_count}: expired=#{expired_count}, " <>
          "ticked=#{tick_count}/#{total_statuses} (#{Float.round(processing_ratio, 2)}%)"
      )
    end

    # Schedule next tick
    timer_ref = Process.send_after(self(), :tick, @tick_interval_ms)
    new_state = %{new_state | tick_timer: timer_ref}

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:force_tick, state) do
    send(self(), :tick)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    total_statuses = StatusStorage.count_all_statuses()

    stats = %{
      tick_count: state.tick_count,
      last_tick_ms: state.last_tick,
      total_statuses: total_statuses,
      due_statuses: state.last_due_statuses,
      processing_ratio: state.processing_ratio,
      tick_interval_ms: @tick_interval_ms,
      efficiency: %{
        percentage_processed: Float.round(state.processing_ratio, 2),
        total_statuses: total_statuses,
        processed_last_tick: state.last_due_statuses
      }
    }

    {:reply, stats, state}
  end

  defp process_expired_statuses(now_ms) do
    expired = StatusStorage.get_expired_statuses(now_ms)

    expired
    |> Enum.chunk_every(@tick_batch_size)
    |> Enum.each(&process_expired_batch/1)

    length(expired)
  end

  defp process_expired_batch(batch) do
    # Group expired statuses by player_id for efficiency
    player_expirations =
      Enum.group_by(batch, fn {{player_id, _status_type}, _entry} -> player_id end)

    # Process each player's expired statuses
    Enum.each(player_expirations, fn {player_id, statuses} ->
      # Process each expired status for this player
      Enum.each(statuses, fn {{^player_id, status_type}, %StatusEntry{} = _entry} ->
        Interpreter.remove_status(player_id, status_type)
      end)

      # Notify the player session to recalculate stats after all expirations are processed
      notify_player_session(player_id)
    end)
  end

  defp process_tick_effects(now_ms) do
    # Get only statuses that are due for ticking, instead of all statuses
    due_statuses = StatusStorage.get_due_statuses(now_ms)

    # Process tick effects in batches
    due_statuses
    |> Enum.chunk_every(@tick_batch_size)
    |> Enum.each(&process_tick_batch(&1, now_ms))

    length(due_statuses)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.Nesting
  defp process_tick_batch(batch, now_ms) do
    # Group status ticks by player_id for efficiency
    player_ticks = Enum.group_by(batch, fn {{player_id, _status_type}, _entry} -> player_id end)

    # Process each player's status ticks
    Enum.each(player_ticks, fn {player_id, statuses} ->
      # Process each status tick for this player
      Enum.each(statuses, fn {{^player_id, status_type}, %StatusEntry{} = entry} ->
        # Process the tick effect using the Interpreter
        Interpreter.process_tick(player_id, status_type)

        # Schedule next tick based on the status's tick value
        # Default to 1000ms (1 second) if no tick value is specified
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        tick_interval = if entry.tick > 0, do: entry.tick, else: 1000
        next_tick_at = now_ms + tick_interval

        # Update the next tick time efficiently
        StatusStorage.update_next_tick(player_id, status_type, next_tick_at)
      end)

      # Notify the player session to recalculate stats after processing all statuses
      notify_player_session(player_id)
    end)
  end

  # Notifies a player session to recalculate stats after status changes
  defp notify_player_session(player_id) do
    case :ets.lookup(:zone_players, player_id) do
      [{^player_id, pid, _account_id}] ->
        # Trigger stats recalculation in the player session
        # Use asynchronous version (false) for better performance
        PlayerSession.recalculate_stats(pid, false)

      _ ->
        # Player not found or offline
        :ok
    end
  end
end
