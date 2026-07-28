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
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

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
    # Group expired statuses by unit for efficiency
    unit_expirations =
      Enum.group_by(batch, fn {{unit_type, unit_id, _status_type}, _entry} ->
        {unit_type, unit_id}
      end)

    Enum.each(unit_expirations, fn {{unit_type, unit_id}, statuses} ->
      if UnitRegistry.unit_exists?(unit_type, unit_id) do
        process_unit_expirations(unit_type, unit_id, statuses)
      else
        clear_orphaned_statuses(unit_type, unit_id, statuses)
      end
    end)
  end

  defp process_unit_expirations(unit_type, unit_id, statuses) do
    removed_status_types =
      Enum.reduce(statuses, [], fn
        {{^unit_type, ^unit_id, status_type}, %StatusEntry{} = entry}, removed ->
          if Interpreter.expire_status_if_current(unit_type, unit_id, status_type, entry) do
            [status_type | removed]
          else
            removed
          end
      end)

    case {unit_type, removed_status_types} do
      {:player, [_ | _]} ->
        notify_player_status_expiration(unit_id)

      {_unit_type, status_types} ->
        Enum.each(status_types, fn status_type ->
          notify_mob_session(unit_type, unit_id, status_type, :expired)
        end)
    end
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

  defp process_tick_batch(batch, now_ms) do
    # Group status ticks by unit for efficiency
    unit_ticks =
      Enum.group_by(batch, fn {{unit_type, unit_id, _status_type}, _entry} ->
        {unit_type, unit_id}
      end)

    Enum.each(unit_ticks, fn {{unit_type, unit_id}, statuses} ->
      if UnitRegistry.unit_exists?(unit_type, unit_id) do
        process_unit_ticks(unit_type, unit_id, statuses, now_ms)
      else
        clear_orphaned_statuses(unit_type, unit_id, statuses)
      end
    end)
  end

  defp process_unit_ticks(unit_type, unit_id, statuses, now_ms) do
    Enum.each(statuses, fn {{^unit_type, ^unit_id, status_type}, %StatusEntry{} = entry} ->
      # Process the tick effect using the Interpreter
      Interpreter.process_tick(unit_type, unit_id, status_type)

      # Schedule next tick based on the status's tick value; only statuses
      # with a positive tick interval ever enter the due set
      tick_interval = if entry.tick > 0, do: entry.tick, else: 1000

      # Update the next tick time efficiently
      StatusStorage.update_next_tick(unit_type, unit_id, status_type, now_ms + tick_interval)

      notify_mob_session(unit_type, unit_id, status_type, :tick)
    end)

    # Notify the unit to recalculate stats after processing all statuses
    # For now, only notify player sessions
    if unit_type == :player do
      notify_player_session(unit_id)
    end
  end

  # A unit can vanish without running its cleanup (killed session, node
  # restart), leaving its statuses behind in StatusStorage. Processing them
  # would crash on the missing unit, so drop them and keep ticking.
  defp clear_orphaned_statuses(unit_type, unit_id, statuses) do
    Logger.warning(
      "Clearing #{length(statuses)} orphaned status(es) for missing #{unit_type} #{unit_id}"
    )

    StatusStorage.clear_unit_statuses(unit_type, unit_id)
  end

  # Expiration can change both stats and status-driven state such as walk speed.
  defp notify_player_status_expiration(player_id) do
    PubSub.broadcast(Aesir.PubSub, "player:#{player_id}", :recalculate_stats)
  end

  # Broadcast on the player's topic so this manager stays decoupled from
  # player session pids; an offline player simply has no subscriber.
  defp notify_player_session(player_id) do
    PubSub.broadcast(Aesir.PubSub, "player:#{player_id}", {:stats, :recalculate})
  end

  # Signals a mob's session that one of its statuses ticked or expired. Unlike
  # players, mobs have no cached stats to recompute (combat numbers are folded
  # live in MobState.to_combatant/1) and their display delta is already
  # broadcast by the interpreter, so this is a per-status cast the MobSession
  # hooks into for generic status-based cast interruption. A mob no
  # longer in the registry simply has no session to notify.
  defp notify_mob_session(:mob, instance_id, status_id, event) do
    case UnitRegistry.get_unit(:mob, instance_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        MobSession.notify_status_changed(pid, status_id, event)

      _ ->
        :ok
    end
  end

  defp notify_mob_session(_unit_type, _unit_id, _status_id, _event), do: :ok
end
