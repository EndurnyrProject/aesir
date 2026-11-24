defmodule Aesir.ZoneServer.Npc.Session do
  @moduledoc """
  A GenServer owning one NPC placement's runtime state: its rAthena-style
  timer and its `enabled`/`hidden`/`cloaked` flags.

  One process per gid, spawned on demand (`ensure_started/1`) under
  `Aesir.ZoneServer.Npc.SessionDynamicSupervisor` and registered in
  `Aesir.ZoneServer.Npc.SessionRegistry`.

  ## Timer model

  rAthena gives each NPC a single timer, not one per label: the schedule is
  the module's `OnTimer<ms>` labels (from `events/0`), parsed and sorted
  ascending. Starting the timer at an elapsed time arms a single
  `Process.send_after/3` for the first label due strictly after it, as
  `npc_timerevent_start` does — never a polling tick. When it fires, the
  label's callback runs and the next label is armed immediately, computing
  its delay from the current elapsed time (a monotonic-based read) rather
  than accumulating drift off the previous delay.

  After the last label fires the timer goes idle: elapsed keeps counting
  (scripts loop by calling `init_timer/1` again, typically from the last
  label). `init_timer/1` (rAthena `initnpctimer`) starts it from zero;
  `start_timer/1` (`startnpctimer`) resumes a stopped timer from its frozen
  elapsed time and leaves a running one alone; `set_timer/2`
  (`setnpctimer`, `npc_settimerevent_tick`) sets the elapsed time, restarting
  from it when the timer runs. `stop_timer/1` cancels the pending fire and
  freezes elapsed; `get_timer/1` reads it back, monotonic-based while
  running/idle, frozen while stopped.

  ## Dispatch decoupling

  A fired label invokes the `:on_fire` callback (`(gid, label) -> any()`)
  handed to `start_link/1`, always in a detached task under
  `Aesir.ZoneServer.Npc.InteractionSupervisor` — never inside this process.
  `ensure_started/1` spawns sessions defaulting `:on_fire` to
  `Aesir.ZoneServer.Npc.Events.trigger_gid/2`, the real event dispatcher;
  tests inject their own callback through `start_link/1`'s opts.

  ## Flags

  The three flags are rAthena's independent NPC view states
  (`npc_enable_target` in `src/map/npc.cpp`): `enabled` is the inverse of
  `is_invisible` (`enablenpc`/`disablenpc`), `hidden` is `OPTION_HIDE`
  (`hideonnpc`/`hideoffnpc`) and `cloaked` is `OPTION_CLOAK`
  (`cloakonnpc`/`cloakoffnpc`). As in the reference, disabling also sets
  `hidden` and enabling also clears it; `cloaked` is only changed by the cloak
  commands.

  Each consumer reads the states its reference function reads: `visible?/1`
  (shown to clients) needs all three clear, `touchable?/1` (the OnTouch area
  scans, `npc_touch_areanpc`/`npc_touch_areanpc2`) ignores `hidden`,
  `hidden?/1` alone gates a click (`npc_click`) and the nearby-NPC check
  (`npc_isnear_sub`), and `enabled?/1` alone gates an attached event
  (`npc_event_sub`).

  `set_enabled/2`, `set_hidden/2` and `set_cloaked/2` write this process's
  state and mirror it to the public `:npc_session_flags` ETS table as
  `{gid, enabled?, hidden?, cloaked?}`, so the reads are lock-free with no
  GenServer call; a missing row means enabled, not hidden and not cloaked
  (so visible). The table is owned by
  `Aesir.ZoneServer.Npc.SessionSupervisor`, not by any one session, so it
  survives a session crash. A session clears its own row on init and on
  terminate, so a crashed (and, under the dynamic supervisor, restarted)
  session resets to defaults.

  An NPC is visible iff enabled, not hidden and not cloaked. When a flag
  change flips that effective visibility, this process
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
  use TypedStruct

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @flags_table :npc_session_flags
  @display_table :npc_display_overrides
  @interaction_supervisor Aesir.ZoneServer.Npc.InteractionSupervisor
  @session_registry Aesir.ZoneServer.Npc.SessionRegistry
  @session_dynamic_supervisor Aesir.ZoneServer.Npc.SessionDynamicSupervisor

  @on_timer_pattern ~r/^OnTimer(\d+)$/

  @typedoc "An `OnTimer<ms>` schedule entry."
  @type timer_entry :: {non_neg_integer(), String.t()}

  @typedoc "The timer's run state: idle before/after its schedule, running mid-schedule, or stopped."
  @type status :: :stopped | :running | :idle

  @typedoc "A per-NPC display override: `sprite`/`name` are `nil` when not overridden."
  @type display_override() :: %{
          sprite: non_neg_integer() | nil,
          name: String.t() | nil,
          size: non_neg_integer()
        }

  @typedoc "Display fields to replace. A missing field keeps its current value."
  @type display_update :: %{
          optional(:sprite) => non_neg_integer() | nil,
          optional(:name) => String.t() | nil,
          optional(:size) => non_neg_integer()
        }

  @typep timer_callback :: (non_neg_integer(), String.t() -> term())
  @typep start_options :: [gid: non_neg_integer(), on_fire: timer_callback()]

  @typedoc "Per-NPC timer, visibility, and appearance state."
  typedstruct enforce: true do
    field :gid, non_neg_integer()
    field :schedule, [timer_entry()], default: []
    field :pending, [timer_entry()], default: []
    field :status, status(), default: :stopped
    field :start_mono, integer() | nil, default: nil
    field :frozen_elapsed, integer(), default: 0
    field :timer_ref, reference() | nil, default: nil
    field :on_fire, timer_callback()
    field :enabled?, boolean(), default: true
    field :hidden?, boolean(), default: false
    field :cloaked?, boolean(), default: false
    field :display, display_override(), default: %{sprite: nil, name: nil, size: 0}
  end

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
  Resumes a stopped timer from its frozen elapsed time, starting the session
  if needed. A running or idle timer is left unchanged.
  """
  @spec start_timer(non_neg_integer()) :: :ok
  def start_timer(gid) do
    gid |> ensure_started() |> GenServer.call(:start_timer)
  end

  @doc """
  Sets the timer's elapsed milliseconds, starting the session if needed. A
  stopped timer stays stopped at `ms`; a running or idle one restarts from it.
  """
  @spec set_timer(non_neg_integer(), integer()) :: :ok
  def set_timer(gid, ms) do
    gid |> ensure_started() |> GenServer.call({:set_timer, ms})
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
  @spec get_timer(non_neg_integer()) :: integer()
  def get_timer(gid) do
    case whereis(gid) do
      nil -> 0
      pid -> GenServer.call(pid, :get_timer)
    end
  end

  @doc """
  Sets the NPC's `enabled` flag, starting the session if needed.

  Like rAthena's `NPCVIEW_ENABLE`/`NPCVIEW_DISABLE`, enabling also clears the
  `hidden` flag and disabling also sets it; `cloaked` is left unchanged.
  """
  @spec set_enabled(non_neg_integer(), boolean()) :: :ok
  def set_enabled(gid, enabled?) do
    gid |> ensure_started() |> GenServer.call({:set_enabled, enabled?})
  end

  @doc "Sets the NPC's `hidden` flag, starting the session if needed."
  @spec set_hidden(non_neg_integer(), boolean()) :: :ok
  def set_hidden(gid, hidden?) do
    gid |> ensure_started() |> GenServer.call({:set_hidden, hidden?})
  end

  @doc "Sets the NPC's `cloaked` flag, starting the session if needed."
  @spec set_cloaked(non_neg_integer(), boolean()) :: :ok
  def set_cloaked(gid, cloaked?) do
    gid |> ensure_started() |> GenServer.call({:set_cloaked, cloaked?})
  end

  @doc """
  Reads the NPC's `enabled` flag directly from ETS, no GenServer call.

  A gid with no row (no session, or a session that never toggled it) is
  enabled by default.
  """
  @spec enabled?(non_neg_integer()) :: boolean()
  def enabled?(gid) do
    case :ets.lookup(@flags_table, gid) do
      [{^gid, enabled?, _hidden?, _cloaked?}] -> enabled?
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
      [{^gid, _enabled?, hidden?, _cloaked?}] -> hidden?
      [] -> false
    end
  end

  @doc """
  Reads the NPC's `cloaked` flag directly from ETS, no GenServer call.

  A gid with no row (no session, or a session that never toggled it) is not
  cloaked by default.
  """
  @spec cloaked?(non_neg_integer()) :: boolean()
  def cloaked?(gid) do
    case :ets.lookup(@flags_table, gid) do
      [{^gid, _enabled?, _hidden?, cloaked?}] -> cloaked?
      [] -> false
    end
  end

  @doc """
  Reads the NPC's effective visibility directly from ETS, no GenServer call:
  visible iff enabled, not hidden and not cloaked.

  A single lookup rather than one per flag, so the per-player movement diff
  pays one ETS read per NPC.
  """
  @spec visible?(non_neg_integer()) :: boolean()
  def visible?(gid) do
    case :ets.lookup(@flags_table, gid) do
      [{^gid, enabled?, hidden?, cloaked?}] -> enabled? and not hidden? and not cloaked?
      [] -> true
    end
  end

  @doc """
  Whether the NPC's OnTouch area can fire, read directly from ETS: enabled and
  not cloaked. `hidden` does not block a touch, as in rAthena's
  `npc_touch_areanpc` (`is_invisible`, `npc_is_cloaked`) and
  `npc_touch_areanpc2` (`is_invisible || option&OPTION_CLOAK`).
  """
  @spec touchable?(non_neg_integer()) :: boolean()
  def touchable?(gid) do
    case :ets.lookup(@flags_table, gid) do
      [{^gid, enabled?, _hidden?, cloaked?}] -> enabled? and not cloaked?
      [] -> true
    end
  end

  @doc """
  Sets a partial display override for the NPC (sprite, display name, and/or
  size), starting the session if needed. Each of `:sprite`, `:name`, and
  `:size` present in `overrides` replaces the current value; absent keys keep
  it. Mirrors the override to `:npc_display_overrides` and re-broadcasts the
  NPC's spawn packet to players in range when it is currently visible, so a
  standing player sees the change immediately.
  """
  @spec set_display(non_neg_integer(), display_update()) :: :ok
  def set_display(gid, overrides) do
    gid |> ensure_started() |> GenServer.call({:set_display, overrides})
  end

  @doc """
  Reads the NPC's raw display override directly from ETS, no GenServer call.

  Returns `{sprite, name, size}` where `sprite`/`name` are `nil` when not
  overridden and `size` defaults to `0` (normal); returns `nil` when the NPC
  has no override row. Callers merge these with the placement's defaults.
  """
  @spec display_override(non_neg_integer()) ::
          {non_neg_integer() | nil, String.t() | nil, non_neg_integer()} | nil
  def display_override(gid) do
    case :ets.lookup(@display_table, gid) do
      [{^gid, sprite, name, size}] -> {sprite, name, size}
      [] -> nil
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
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    gid = Keyword.fetch!(opts, :gid)
    GenServer.start_link(__MODULE__, opts, name: via(gid))
  end

  @doc false
  @spec child_spec(start_options()) :: Supervisor.child_spec()
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
    clear_display(gid)

    state = %__MODULE__{
      gid: gid,
      schedule: timer_schedule(gid),
      on_fire: on_fire
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:init_timer, _from, state) do
    {:reply, :ok, start_at(state, 0)}
  end

  @impl GenServer
  def handle_call(:start_timer, _from, %{status: :stopped} = state) do
    {:reply, :ok, start_at(state, state.frozen_elapsed)}
  end

  def handle_call(:start_timer, _from, state), do: {:reply, :ok, state}

  @impl GenServer
  def handle_call({:set_timer, ms}, _from, %{status: :stopped} = state) do
    {:reply, :ok, %{state | frozen_elapsed: ms}}
  end

  def handle_call({:set_timer, ms}, _from, state), do: {:reply, :ok, start_at(state, ms)}

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
    new_state = %{state | enabled?: enabled?, hidden?: not enabled?} |> mirror_flags()
    broadcast_visibility_transition(state, new_state)
    if enabled?, do: recheck_touch_area(state.gid)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_hidden, hidden?}, _from, state) do
    new_state = %{state | hidden?: hidden?} |> mirror_flags()
    broadcast_visibility_transition(state, new_state)
    unless hidden?, do: recheck_touch_area(state.gid)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_cloaked, cloaked?}, _from, state) do
    new_state = %{state | cloaked?: cloaked?} |> mirror_flags()
    broadcast_visibility_transition(state, new_state)
    unless cloaked?, do: recheck_touch_area(state.gid)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_display, overrides}, _from, state) do
    new_state = %{state | display: merge_display(state.display, overrides)} |> mirror_display()
    broadcast_display_change(state, new_state)
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
    clear_display(state.gid)
    :ok
  end

  # Private Functions

  @spec via(non_neg_integer()) :: GenServer.name()
  defp via(gid), do: {:via, Registry, {session_registry(), gid}}

  @spec whereis(non_neg_integer()) :: pid() | nil
  defp whereis(gid) do
    case Registry.lookup(session_registry(), gid) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  @spec start_child(non_neg_integer()) :: pid()
  defp start_child(gid) do
    case DynamicSupervisor.start_child(session_dynamic_supervisor(), {__MODULE__, gid: gid}) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  defp session_registry do
    ProcessTree.get({@session_registry, :server}) || @session_registry
  end

  defp session_dynamic_supervisor do
    ProcessTree.get({@session_dynamic_supervisor, :server}) || @session_dynamic_supervisor
  end

  # Runs the timer from `elapsed_ms`: only labels due strictly after it are
  # pending, as `npc_timerevent_start` picks the first `timer > nd->u.scr.timer`.
  @spec start_at(t(), integer()) :: t()
  defp start_at(state, elapsed_ms) do
    pending = Enum.filter(state.schedule, fn {due_ms, _label} -> due_ms > elapsed_ms end)

    %{state | pending: pending, start_mono: now_ms() - elapsed_ms, frozen_elapsed: 0}
    |> arm_next(elapsed_ms)
  end

  # `elapsed_ms` is the caller's authoritative elapsed reading, taken
  # explicitly rather than re-derived from `state` here: at the init_timer
  # call site `status` hasn't yet flipped away from :stopped when this runs,
  # so `elapsed_now/1`'s :stopped clause would silently answer from
  # whatever `frozen_elapsed` happens to hold instead of the just-reset 0.
  @spec arm_next(t(), integer()) :: t()
  defp arm_next(%{pending: []} = state, _elapsed_ms), do: %{state | status: :idle, timer_ref: nil}

  defp arm_next(%{pending: [{due_ms, label} | rest]} = state, elapsed_ms) do
    ref = make_ref()
    delay = max(due_ms - elapsed_ms, 0)
    Process.send_after(self(), {:timer_fire, ref, label}, delay)
    %{state | status: :running, timer_ref: ref, pending: rest}
  end

  @spec elapsed_now(t()) :: integer()
  defp elapsed_now(%{status: :stopped, frozen_elapsed: frozen_elapsed}), do: frozen_elapsed
  defp elapsed_now(%{start_mono: nil}), do: 0
  defp elapsed_now(%{start_mono: start_mono}), do: now_ms() - start_mono

  @spec now_ms() :: integer()
  defp now_ms, do: System.monotonic_time(:millisecond)

  @spec dispatch(non_neg_integer(), String.t(), timer_callback()) :: :ok
  defp dispatch(gid, label, on_fire) do
    _ =
      Task.Supervisor.start_child(interaction_supervisor(), fn -> on_fire.(gid, label) end)

    :ok
  end

  defp interaction_supervisor do
    ProcessTree.get({@interaction_supervisor, :server}) || @interaction_supervisor
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
  defp mirror_flags(%{gid: gid, enabled?: enabled?, hidden?: hidden?, cloaked?: cloaked?} = state) do
    :ets.insert(@flags_table, {gid, enabled?, hidden?, cloaked?})
    state
  end

  @spec clear_flags(non_neg_integer()) :: true
  defp clear_flags(gid), do: :ets.delete(@flags_table, gid)

  @spec merge_display(display_override(), display_update()) :: display_override()
  defp merge_display(current, overrides) do
    %{
      sprite: Map.get(overrides, :sprite, current.sprite),
      name: Map.get(overrides, :name, current.name),
      size: Map.get(overrides, :size, current.size)
    }
  end

  @spec mirror_display(t()) :: t()
  defp mirror_display(%{gid: gid, display: %{sprite: sprite, name: name, size: size}} = state) do
    :ets.insert(@display_table, {gid, sprite, name, size})
    state
  end

  @spec clear_display(non_neg_integer()) :: true
  defp clear_display(gid), do: :ets.delete(@display_table, gid)

  @spec broadcast_display_change(t(), t()) :: :ok
  defp broadcast_display_change(_old_state, new_state) do
    if effectively_visible?(new_state), do: broadcast_spawn(new_state.gid)
    :ok
  end

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
  defp effectively_visible?(%{enabled?: enabled?, hidden?: hidden?, cloaked?: cloaked?}),
    do: enabled? and not hidden? and not cloaked?

  # Enabling, unhiding or uncloaking an NPC (rAthena's `NPCVIEW_VISIBLE`)
  # re-runs the touch check of every player standing in its trigger area,
  # whether or not the flip made it visible: the player's own check reads the
  # flags again (`npc_enable_sub`).
  @spec recheck_touch_area(non_neg_integer()) :: :ok
  defp recheck_touch_area(gid) do
    with_entry(gid, fn
      {_module, %Placement{trigger: {xs, ys}} = placement} ->
        placement.map
        |> SpatialIndex.get_players_in_area(
          placement.x - xs,
          placement.y - ys,
          placement.x + xs,
          placement.y + ys
        )
        |> Enum.each(&recheck_player_touch/1)

      _no_area ->
        :ok
    end)
  end

  defp recheck_player_touch(char_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %{map_name: map, x: x, y: y}, pid}} when is_pid(pid) ->
        PlayerSession.recheck_touch(pid, {map, x, y})

      _gone ->
        :ok
    end
  end

  @spec broadcast_spawn(non_neg_integer()) :: :ok
  defp broadcast_spawn(gid) do
    with_entry(gid, fn {_module, placement} = entry ->
      case NpcPackets.spawn_packet(entry) do
        :invisible -> :ok
        packet -> broadcast_to_range(placement, packet)
      end
    end)
  end

  @spec broadcast_vanish(non_neg_integer()) :: :ok
  defp broadcast_vanish(gid) do
    with_entry(gid, fn {_module, placement} ->
      broadcast_to_range(placement, NpcPackets.vanish_packet(gid))
    end)
  end

  @spec broadcast_to_range(Placement.t(), struct()) :: :ok
  defp broadcast_to_range(placement, packet) do
    Broadcast.to_in_range(placement.map, placement.x, placement.y, Config.view_range(), packet)
  end

  @spec with_entry(non_neg_integer(), (NpcRegistry.entry() -> :ok)) :: :ok
  defp with_entry(gid, fun) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, entry} -> fun.(entry)
      :error -> :ok
    end
  end
end
