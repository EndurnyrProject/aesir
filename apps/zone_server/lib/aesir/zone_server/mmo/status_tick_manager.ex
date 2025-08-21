defmodule Aesir.ZoneServer.Mmo.StatusTickManager do
  @moduledoc """
  Single process that manages all status tick effects and expirations.
  Runs on a fixed interval and batch processes all status updates.
  """

  use GenServer
  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  # 1 second tick rate
  @tick_interval_ms 1000
  # Process statuses in batches
  @tick_batch_size 100

  defmodule State do
    defstruct [
      :tick_timer,
      tick_count: 0,
      last_tick: 0
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

    # Update state
    new_state = %{state | tick_count: state.tick_count + 1, last_tick: now_ms}

    # Log stats periodically (every 60 ticks)
    if rem(new_state.tick_count, 60) == 0 do
      Logger.debug(
        "StatusTick ##{new_state.tick_count}: expired=#{expired_count}, ticked=#{tick_count}"
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
    stats = %{
      tick_count: state.tick_count,
      last_tick_ms: state.last_tick,
      total_statuses: StatusStorage.count_all_statuses(),
      tick_interval_ms: @tick_interval_ms
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
    Enum.each(batch, fn {{player_id, status_type}, _entry} ->
      Interpreter.remove_status(player_id, status_type)
    end)
  end

  defp process_tick_effects(_now_ms) do
    # Get all active statuses and process ticks through interpreter
    all_statuses = StatusStorage.get_all_statuses()

    # Process tick effects in batches
    all_statuses
    |> Enum.chunk_every(@tick_batch_size)
    |> Enum.each(&process_tick_batch/1)

    length(all_statuses)
  end

  defp process_tick_batch(batch) do
    Enum.each(batch, fn {{player_id, status_type}, _entry} ->
      Interpreter.process_tick(player_id, status_type)
    end)
  end
end
