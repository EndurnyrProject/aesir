defmodule Aesir.ZoneServer.Mmo.StatusTickManager do
  @moduledoc """
  Runs every status's interval ticks and expiry on exact deadlines.

  Each live status owns one timer, armed at the earlier of its next tick and
  its expiry (`arm/3`, called by the interpreter after every store). When it
  fires, a tick that is due runs first and its next deadline is anchored to the
  tick's own deadline, not to the processing time; a tick run more than a second
  late anchors to the present instead. The entry is then re-read: an expiry that
  is due ends the status (a tick landing on the expiry runs before it), anything
  else re-arms from storage, so an expiry pushed later simply waits longer. A
  deadline whose stored generation changed is dropped and the replacement is
  armed from storage. A writer that shortens a stored deadline through
  `StatusStorage.update_status/4` must call `arm/3` afterwards.

  `schedule_exact_tick/5` is the loop of statuses that drive their own
  countdown (Venom Splasher): a generation-tagged deadline that continues from
  the prior deadline while the callback keeps the status.

  `force_tick/0` sweeps storage for everything already due (tests and
  diagnostics); `init/1` arms whatever storage holds, so a restarted manager
  loses no deadline.
  """

  use GenServer
  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @exact_tick_interval_ms 500
  @late_deadline_ms 1_000

  defmodule State do
    @moduledoc false
    defstruct timers: %{}

    @type key :: {atom(), integer(), atom()}
    @type t :: %__MODULE__{timers: %{key() => {reference(), pos_integer(), integer()}}}
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc "Processes every status whose tick or expiry is already due."
  @spec force_tick() :: :ok
  def force_tick do
    GenServer.cast(server(), :force_tick)
  end

  @doc """
  Arms the deadline timer of a stored status entry.

  Re-arming the same generation at the same deadline is a no-op; a changed
  deadline replaces the pending timer. An entry older than the pending timer's
  generation is ignored, and an entry without a tick or an expiry disarms any
  pending timer.
  """
  @spec arm(atom(), integer(), StatusEntry.t()) :: :ok
  def arm(unit_type, unit_id, %StatusEntry{} = entry) do
    GenServer.cast(server(), {:arm, unit_type, unit_id, entry})
  end

  @doc "Schedules a generation-tagged status tick for an absolute monotonic deadline."
  @spec schedule_exact_tick(atom(), integer(), atom(), pos_integer(), integer()) :: :ok
  def schedule_exact_tick(unit_type, unit_id, status_id, generation, due_at) do
    GenServer.cast(
      server(),
      {:schedule_exact_tick, unit_type, unit_id, status_id, generation, due_at}
    )
  end

  defp server do
    ProcessTree.get({__MODULE__, :server}) || __MODULE__
  end

  @impl true
  def init(_opts) do
    state =
      Enum.reduce(StatusStorage.get_all_statuses(), %State{}, fn
        {{unit_type, unit_id, _status_id}, entry}, state ->
          arm_entry(state, unit_type, unit_id, entry)
      end)

    {:ok, state}
  end

  @impl true
  def handle_info({:status_timer, key, generation, due_at}, state) do
    case Map.get(state.timers, key) do
      {_ref, ^generation, ^due_at} ->
        state = %{state | timers: Map.delete(state.timers, key)}
        {:noreply, process_deadline(state, key, generation, due_at)}

      _rearmed_or_cancelled ->
        {:noreply, state}
    end
  end

  def handle_info(
        {:exact_status_tick, unit_type, unit_id, status_id, generation, due_at},
        state
      ) do
    if Interpreter.process_tick_if_current(unit_type, unit_id, status_id, generation) == :continue do
      schedule_exact_message(
        unit_type,
        unit_id,
        status_id,
        generation,
        due_at + @exact_tick_interval_ms
      )
    end

    {:noreply, state}
  end

  def handle_info(:tick, state) do
    now_ms = System.monotonic_time(:millisecond)

    due =
      (StatusStorage.get_expired_statuses(now_ms) ++ StatusStorage.get_due_statuses(now_ms))
      |> Enum.uniq_by(fn {key, _entry} -> key end)

    state =
      Enum.reduce(due, state, fn {key, %StatusEntry{generation: generation}}, state ->
        process_deadline(state, key, generation, now_ms)
      end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:arm, unit_type, unit_id, %StatusEntry{} = entry}, state) do
    {:noreply, arm_entry(state, unit_type, unit_id, entry)}
  end

  def handle_cast(
        {:schedule_exact_tick, unit_type, unit_id, status_id, generation, due_at},
        state
      ) do
    schedule_exact_message(unit_type, unit_id, status_id, generation, due_at)
    {:noreply, state}
  end

  def handle_cast(:force_tick, state) do
    send(self(), :tick)
    {:noreply, state}
  end

  defp schedule_exact_message(unit_type, unit_id, status_id, generation, due_at) do
    delay = max(due_at - System.monotonic_time(:millisecond), 0)

    Process.send_after(
      self(),
      {:exact_status_tick, unit_type, unit_id, status_id, generation, due_at},
      delay
    )
  end

  # Timer bookkeeping

  defp arm_entry(
         state,
         unit_type,
         unit_id,
         %StatusEntry{type: status_id, generation: generation} = entry
       ) do
    key = {unit_type, unit_id, status_id}

    case {deadline(entry), Map.get(state.timers, key)} do
      {nil, nil} ->
        state

      {nil, {ref, _generation, _due_at}} ->
        Process.cancel_timer(ref)
        %{state | timers: Map.delete(state.timers, key)}

      {due_at, {_ref, ^generation, due_at}} ->
        state

      {_due_at, {_ref, pending_generation, _pending_due}} when pending_generation > generation ->
        state

      {due_at, pending} ->
        if pending, do: Process.cancel_timer(elem(pending, 0))
        delay = max(due_at - System.monotonic_time(:millisecond), 0)
        ref = Process.send_after(self(), {:status_timer, key, generation, due_at}, delay)
        %{state | timers: Map.put(state.timers, key, {ref, generation, due_at})}
    end
  end

  defp deadline(%StatusEntry{next_tick_at: next_tick_at, expires_at: expires_at}) do
    [next_tick_at, expires_at]
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> nil end)
  end

  defp rearm(state, {unit_type, unit_id, status_id}) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{} = entry -> arm_entry(state, unit_type, unit_id, entry)
      nil -> state
    end
  end

  # Deadline processing

  defp process_deadline(state, {unit_type, unit_id, status_id} = key, generation, due_at) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{generation: ^generation} = entry ->
        if UnitRegistry.unit_exists?(unit_type, unit_id) do
          run_deadline(unit_type, unit_id, entry, due_at)
          rearm(state, key)
        else
          clear_orphaned_status(unit_type, unit_id, status_id)
          state
        end

      _replaced_or_removed ->
        rearm(state, key)
    end
  end

  defp run_deadline(unit_type, unit_id, %StatusEntry{type: status_id} = entry, due_at) do
    if tick_due?(entry, due_at), do: run_tick(unit_type, unit_id, entry)

    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{generation: generation} = current when generation == entry.generation ->
        if expiry_due?(current, due_at), do: run_expiry(unit_type, unit_id, current)

      _replaced_or_removed ->
        :ok
    end
  end

  defp tick_due?(%StatusEntry{next_tick_at: next_tick_at}, due_at),
    do: is_integer(next_tick_at) and next_tick_at <= due_at

  defp expiry_due?(%StatusEntry{expires_at: expires_at}, due_at),
    do: is_integer(expires_at) and expires_at <= due_at

  defp run_tick(unit_type, unit_id, %StatusEntry{type: status_id} = entry) do
    Interpreter.process_tick_if_current(unit_type, unit_id, status_id, entry.generation)

    advance_next_tick(
      unit_type,
      unit_id,
      status_id,
      entry.generation,
      entry.next_tick_at,
      next_tick_deadline(entry)
    )

    notify_unit_session(unit_type, unit_id, status_id, :tick)
    if unit_type == :player, do: notify_player_session(unit_id)
  end

  # The next tick is anchored to this tick's deadline, unless the tick ran more
  # than a second late, in which case it anchors to the present.
  defp next_tick_deadline(%StatusEntry{next_tick_at: next_tick_at, tick: tick}) do
    now_ms = System.monotonic_time(:millisecond)
    anchor = if now_ms - next_tick_at > @late_deadline_ms, do: now_ms, else: next_tick_at
    anchor + tick
  end

  # Compare-and-swap on the exact entry: a tick that replaced its own status, or a
  # concurrent re-application, leaves the newer entry untouched.
  defp advance_next_tick(unit_type, unit_id, status_id, generation, from, to) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{generation: ^generation, next_tick_at: ^from} = current ->
        updated = %{current | next_tick_at: to, tick_count: current.tick_count + 1}

        if StatusStorage.replace_status_if_current(
             unit_type,
             unit_id,
             status_id,
             current,
             updated
           ),
           do: :ok,
           else: advance_next_tick(unit_type, unit_id, status_id, generation, from, to)

      _replaced_or_advanced ->
        :ok
    end
  end

  defp run_expiry(unit_type, unit_id, %StatusEntry{type: status_id} = entry) do
    if Interpreter.expire_status_if_current(unit_type, unit_id, status_id, entry) do
      Interpreter.run_timeout(unit_type, unit_id, status_id, entry)

      if unit_type == :player,
        do: notify_player_status_expiration(unit_id),
        else: notify_unit_session(unit_type, unit_id, status_id, :expired)
    end
  end

  # A unit can vanish without running its cleanup (killed session, node
  # restart), leaving its statuses behind in StatusStorage. Processing them
  # would crash on the missing unit, so drop them and keep ticking.
  defp clear_orphaned_status(unit_type, unit_id, status_id) do
    Logger.warning("Clearing orphaned status #{status_id} of missing #{unit_type} #{unit_id}")
    StatusStorage.clear_unit_statuses(unit_type, unit_id)
  end

  # Expiration can change both stats and status-driven state such as walk speed.
  defp notify_player_status_expiration(player_id) do
    PubSub.broadcast(Aesir.PubSub, "player:#{player_id}", {:stats, :status_changed})
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
  defp notify_unit_session(:mob, instance_id, status_id, event) do
    case UnitRegistry.get_unit(:mob, instance_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        MobSession.notify_status_changed(pid, status_id, event)

      _ ->
        :ok
    end
  end

  defp notify_unit_session(:homunculus, world_gid, status_id, event) do
    case UnitRegistry.get_unit(:homunculus, world_gid) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        GenServer.cast(pid, {:homunculus, {:status_changed, world_gid, status_id, event}})

      _ ->
        :ok
    end
  end

  defp notify_unit_session(_unit_type, _unit_id, _status_id, _event), do: :ok
end
