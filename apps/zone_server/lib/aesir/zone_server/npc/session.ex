defmodule Aesir.ZoneServer.Npc.Session do
  @moduledoc """
  A GenServer owning one NPC placement's runtime state: its rAthena-style
  timer and its `enabled`/`hidden` flags.

  One process per gid, spawned on demand (`ensure_started/1`) under
  `Aesir.ZoneServer.Npc.SessionDynamicSupervisor` and registered in
  `Aesir.ZoneServer.Npc.SessionRegistry`.

  ## Timer model

  rAthena gives each NPC a single timer, not one per label: the schedule is
  the module's `OnTimer<ms>` labels (from `events/0`), parsed and sorted
  ascending. `init_timer/1` resets elapsed to zero and arms a single
  `Process.send_after/3` for the next due label — never a polling tick. When
  it fires, the label's callback runs and the next label is armed
  immediately, computing its delay from the current elapsed time (a
  monotonic-based read) rather than accumulating drift off the previous
  delay.

  After the last label fires the timer goes idle: elapsed keeps counting
  (scripts loop by calling `init_timer/1` again, typically from the last
  label). `stop_timer/1` cancels the pending fire and freezes elapsed;
  `get_timer/1` reads it back, monotonic-based while running/idle, frozen
  while stopped.

  ## Dispatch decoupling

  A fired label invokes the `:on_fire` callback (`(gid, label) -> any()`)
  handed to `start_link/1`, always in a detached task under
  `Aesir.ZoneServer.Npc.InteractionSupervisor` — never inside this process.
  `ensure_started/1` spawns sessions defaulting `:on_fire` to
  `Aesir.ZoneServer.Npc.Events.trigger_gid/2`, the real event dispatcher;
  tests inject their own callback through `start_link/1`'s opts.

  ## Flags

  `set_enabled/2` and `set_hidden/2` write this process's state and mirror it
  to the public `:npc_session_flags` ETS table, so `enabled?/1`, `hidden?/1`
  and `visible?/1` can read it lock-free with no GenServer call; a missing row
  means enabled/not-hidden (so visible). The table is owned by
  `Aesir.ZoneServer.Npc.SessionSupervisor`, not by any one session, so it
  survives a session crash. A session clears its own row on init and on
  terminate, so a crashed (and, under the dynamic supervisor, restarted)
  session resets to defaults.

  An NPC is visible iff enabled and not hidden. When a `set_enabled/2` or
  `set_hidden/2` call flips that effective visibility, this process
  broadcasts the transition itself (`Npc.Packets.spawn_packet/1` on
  invisible->visible, `vanish_packet/1` on visible->invisible) to every
  player within `Config.view_range/0` of the placement, so a player standing
  still sees the change without waiting for their next movement tick.

  This broadcast never touches `PlayerState.visible_npcs` — that bookkeeping
  is owned by each player's own session, not written here — so it cannot
  desync it: a player's `visible_npcs` simply lags one flag flip behind until
  their next movement tick. `MovementHandler.handle_visibility_update/1`
  recomputes `visible_npcs` from scratch against this same flag filter every
  time it runs, so it always catches up — at worst re-sending one redundant
  spawn or vanish for the gid this broadcast already covered, never leaving
  the player's state stuck out of sync with the flag.
  """

  use GenServer

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Broadcast

  @flags_table :npc_session_flags
  @interaction_supervisor Aesir.ZoneServer.Npc.InteractionSupervisor
  @session_registry Aesir.ZoneServer.Npc.SessionRegistry
  @session_dynamic_supervisor Aesir.ZoneServer.Npc.SessionDynamicSupervisor

  @on_timer_pattern ~r/^OnTimer(\d+)$/

  @typedoc "An `OnTimer<ms>` schedule entry."
  @type timer_entry :: {non_neg_integer(), String.t()}

  @typedoc "The timer's run state: idle before/after its schedule, running mid-schedule, or stopped."
  @type status :: :stopped | :running | :idle

  @enforce_keys [:gid, :on_fire]
  defstruct gid: nil,
            schedule: [],
            pending: [],
            status: :stopped,
            start_mono: nil,
            frozen_elapsed: 0,
            timer_ref: nil,
            on_fire: nil,
            enabled?: true,
            hidden?: false

  @type t() :: %__MODULE__{
          gid: non_neg_integer(),
          schedule: [timer_entry()],
          pending: [timer_entry()],
          status: status(),
          start_mono: integer() | nil,
          frozen_elapsed: non_neg_integer(),
          timer_ref: reference() | nil,
          on_fire: (non_neg_integer(), String.t() -> any()),
          enabled?: boolean(),
          hidden?: boolean()
        }

  # Public API

  @doc """
  Returns the running session for `gid`, starting one on demand.

  Idempotent: concurrent callers for the same gid converge on the same pid.
  """
  @spec ensure_started(non_neg_integer()) :: pid()
  def ensure_started(gid) do
    case whereis(gid) do
      nil -> start_child(gid)
      pid -> pid
    end
  end

  @doc """
  Resets and (re)arms the NPC's timer, starting the session if needed.
  """
  @spec init_timer(non_neg_integer()) :: :ok
  def init_timer(gid) do
    gid |> ensure_started() |> GenServer.call(:init_timer)
  end

  @doc """
  Cancels the pending timer fire and freezes elapsed time.

  A gid with no running session has nothing to stop.
  """
  @spec stop_timer(non_neg_integer()) :: :ok
  def stop_timer(gid) do
    case whereis(gid) do
      nil -> :ok
      pid -> GenServer.call(pid, :stop_timer)
    end
  end

  @doc """
  Returns the NPC timer's elapsed milliseconds.

  A gid with no running session has never had its timer started, so this
  returns `0` without spawning one.
  """
  @spec get_timer(non_neg_integer()) :: non_neg_integer()
  def get_timer(gid) do
    case whereis(gid) do
      nil -> 0
      pid -> GenServer.call(pid, :get_timer)
    end
  end

  @doc "Sets the NPC's `enabled` flag, starting the session if needed."
  @spec set_enabled(non_neg_integer(), boolean()) :: :ok
  def set_enabled(gid, enabled?) do
    gid |> ensure_started() |> GenServer.call({:set_enabled, enabled?})
  end

  @doc "Sets the NPC's `hidden` flag, starting the session if needed."
  @spec set_hidden(non_neg_integer(), boolean()) :: :ok
  def set_hidden(gid, hidden?) do
    gid |> ensure_started() |> GenServer.call({:set_hidden, hidden?})
  end

  @doc """
  Reads the NPC's `enabled` flag directly from ETS, no GenServer call.

  A gid with no row (no session, or a session that never toggled it) is
  enabled by default.
  """
  @spec enabled?(non_neg_integer()) :: boolean()
  def enabled?(gid) do
    case :ets.lookup(@flags_table, gid) do
      [{^gid, enabled?, _hidden?}] -> enabled?
      [] -> true
    end
  end

  @doc """
  Reads the NPC's `hidden` flag directly from ETS, no GenServer call.

  A gid with no row (no session, or a session that never toggled it) is not
  hidden by default.
  """
  @spec hidden?(non_neg_integer()) :: boolean()
  def hidden?(gid) do
    case :ets.lookup(@flags_table, gid) do
      [{^gid, _enabled?, hidden?}] -> hidden?
      [] -> false
    end
  end

  @doc """
  Reads the NPC's effective visibility directly from ETS, no GenServer call:
  visible iff enabled and not hidden.

  A single lookup rather than two `enabled?/1`/`hidden?/1` calls, so the
  per-player movement diff and the click-gating check pay one ETS read each.
  """
  @spec visible?(non_neg_integer()) :: boolean()
  def visible?(gid) do
    case :ets.lookup(@flags_table, gid) do
      [{^gid, enabled?, hidden?}] -> enabled? and not hidden?
      [] -> true
    end
  end

  @doc """
  Starts a session for `gid`.

  Accepts `:on_fire` (defaults to `Aesir.ZoneServer.Npc.Events.trigger_gid/2`,
  the real event dispatcher) as the callback invoked, detached, when a
  scheduled `OnTimer<ms>` label fires. Intended to be started through
  `ensure_started/1`; exposed directly for tests that need to inject a
  callback.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    gid = Keyword.fetch!(opts, :gid)
    GenServer.start_link(__MODULE__, opts, name: via(gid))
  end

  @doc false
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    # :transient, not the GenServer default :permanent: a crash restarts the
    # session blank (see the moduledoc), but a normal stop (terminate_child,
    # app shutdown) must not be resurrected by the dynamic supervisor.
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, restart: :transient}
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    gid = Keyword.fetch!(opts, :gid)
    on_fire = Keyword.get(opts, :on_fire, &Events.trigger_gid/2)

    # A supervisor's terminate_child/2 sends an untrapped :shutdown exit
    # signal, which would kill this process before terminate/2 runs. Trapping
    # exits ensures terminate/2 always clears the flags row, whether this
    # session stops gracefully, is torn down by its supervisor, or crashes.
    Process.flag(:trap_exit, true)

    clear_flags(gid)

    state = %__MODULE__{
      gid: gid,
      schedule: timer_schedule(gid),
      on_fire: on_fire
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:init_timer, _from, state) do
    new_state =
      %{state | pending: state.schedule, start_mono: now_ms(), frozen_elapsed: 0}
      |> arm_next(0)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:stop_timer, _from, state) do
    new_state = %{
      state
      | status: :stopped,
        timer_ref: nil,
        frozen_elapsed: elapsed_now(state),
        start_mono: nil
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_timer, _from, state) do
    {:reply, elapsed_now(state), state}
  end

  @impl GenServer
  def handle_call({:set_enabled, enabled?}, _from, state) do
    new_state = %{state | enabled?: enabled?} |> mirror_flags()
    broadcast_visibility_transition(state, new_state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_hidden, hidden?}, _from, state) do
    new_state = %{state | hidden?: hidden?} |> mirror_flags()
    broadcast_visibility_transition(state, new_state)
    {:reply, :ok, new_state}
  end

  # Only a fire whose ref still matches the currently-armed one, on a timer
  # that's still running, is honored. `Process.cancel_timer/1` cannot
  # guarantee an in-flight message isn't already in the process mailbox, so
  # a fire scheduled by a since-stopped or since-reset timer must be
  # recognizable and dropped rather than relied on to never arrive.
  @impl GenServer
  def handle_info({:timer_fire, ref, label}, %{status: :running, timer_ref: ref} = state) do
    dispatch(state.gid, label, state.on_fire)
    {:noreply, arm_next(state, elapsed_now(state))}
  end

  def handle_info({:timer_fire, _ref, _label}, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    clear_flags(state.gid)
    :ok
  end

  # Private Functions

  @spec via(non_neg_integer()) :: GenServer.name()
  defp via(gid), do: {:via, Registry, {@session_registry, gid}}

  @spec whereis(non_neg_integer()) :: pid() | nil
  defp whereis(gid) do
    case Registry.lookup(@session_registry, gid) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  @spec start_child(non_neg_integer()) :: pid()
  defp start_child(gid) do
    case DynamicSupervisor.start_child(@session_dynamic_supervisor, {__MODULE__, gid: gid}) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  # `elapsed_ms` is the caller's authoritative elapsed reading, taken
  # explicitly rather than re-derived from `state` here: at the init_timer
  # call site `status` hasn't yet flipped away from :stopped when this runs,
  # so `elapsed_now/1`'s :stopped clause would silently answer from
  # whatever `frozen_elapsed` happens to hold instead of the just-reset 0.
  @spec arm_next(t(), non_neg_integer()) :: t()
  defp arm_next(%{pending: []} = state, _elapsed_ms), do: %{state | status: :idle, timer_ref: nil}

  defp arm_next(%{pending: [{due_ms, label} | rest]} = state, elapsed_ms) do
    ref = make_ref()
    delay = max(due_ms - elapsed_ms, 0)
    Process.send_after(self(), {:timer_fire, ref, label}, delay)
    %{state | status: :running, timer_ref: ref, pending: rest}
  end

  @spec elapsed_now(t()) :: non_neg_integer()
  defp elapsed_now(%{status: :stopped, frozen_elapsed: frozen_elapsed}), do: frozen_elapsed
  defp elapsed_now(%{start_mono: nil}), do: 0
  defp elapsed_now(%{start_mono: start_mono}), do: now_ms() - start_mono

  @spec now_ms() :: integer()
  defp now_ms, do: System.monotonic_time(:millisecond)

  @spec dispatch(non_neg_integer(), String.t(), (non_neg_integer(), String.t() -> any())) :: :ok
  defp dispatch(gid, label, on_fire) do
    _ = Task.Supervisor.start_child(@interaction_supervisor, fn -> on_fire.(gid, label) end)
    :ok
  end

  @spec timer_schedule(non_neg_integer()) :: [timer_entry()]
  defp timer_schedule(gid) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {module, _placement}} ->
        module.events()
        |> Enum.flat_map(&parse_on_timer/1)
        |> Enum.sort_by(fn {due_ms, _label} -> due_ms end)

      :error ->
        []
    end
  end

  @spec parse_on_timer(String.t()) :: [timer_entry()]
  defp parse_on_timer(label) do
    case Regex.run(@on_timer_pattern, label) do
      [_full, ms] -> [{String.to_integer(ms), label}]
      nil -> []
    end
  end

  @spec mirror_flags(t()) :: t()
  defp mirror_flags(%{gid: gid, enabled?: enabled?, hidden?: hidden?} = state) do
    :ets.insert(@flags_table, {gid, enabled?, hidden?})
    state
  end

  @spec clear_flags(non_neg_integer()) :: true
  defp clear_flags(gid), do: :ets.delete(@flags_table, gid)

  # Broadcasts the immediate spawn/vanish delta when a flag change flips this
  # NPC's effective visibility (see the moduledoc's "Flags" section). A
  # change that doesn't flip visibility (e.g. hiding an already-disabled NPC)
  # broadcasts nothing.
  @spec broadcast_visibility_transition(t(), t()) :: :ok
  defp broadcast_visibility_transition(old_state, new_state) do
    case {effectively_visible?(old_state), effectively_visible?(new_state)} do
      {true, false} -> broadcast_vanish(new_state.gid)
      {false, true} -> broadcast_spawn(new_state.gid)
      _unchanged -> :ok
    end
  end

  @spec effectively_visible?(t()) :: boolean()
  defp effectively_visible?(%{enabled?: enabled?, hidden?: hidden?}), do: enabled? and not hidden?

  @spec broadcast_spawn(non_neg_integer()) :: :ok
  defp broadcast_spawn(gid) do
    with_placement(gid, fn placement ->
      broadcast_to_range(placement, NpcPackets.spawn_packet(placement))
    end)
  end

  @spec broadcast_vanish(non_neg_integer()) :: :ok
  defp broadcast_vanish(gid) do
    with_placement(gid, fn placement ->
      broadcast_to_range(placement, NpcPackets.vanish_packet(gid))
    end)
  end

  @spec broadcast_to_range(Placement.t(), struct()) :: :ok
  defp broadcast_to_range(placement, packet) do
    Broadcast.to_in_range(placement.map, placement.x, placement.y, Config.view_range(), packet)
  end

  @spec with_placement(non_neg_integer(), (Placement.t() -> :ok)) :: :ok
  defp with_placement(gid, fun) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} -> fun.(placement)
      :error -> :ok
    end
  end
end
