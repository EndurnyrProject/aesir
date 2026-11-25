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
  ascending. The state is the reference's own three fields: `timer`, the
  elapsed time when the timer last started, stopped or fired a label
  (`nd->u.scr.timer`); `timertick`, the monotonic time it started ticking
  from, `nil` when it is not ticking (`nd->u.scr.timertick`); and `armed`,
  the one pending fire (`nd->u.scr.timerid`). Each command is a direct
  transcription of its reference function:

  - starting (`npc_timerevent_start`) does nothing when already armed or
    ticking; otherwise it arms a single `Process.send_after/3` for the first
    label due strictly after `timer` (never a polling tick) and starts
    ticking. With no label left it only ticks (idle).
  - stopping (`npc_timerevent_stop`) disarms, and when ticking folds the
    ticked time into `timer` and stops ticking.
  - setting (`npc_settimerevent_tick`) stops a started timer, sets `timer`,
    and starts it again if it was started.
  - reading (`npc_gettimerevent_tick`) is `timer` plus the time ticked since
    `timertick`.

  `init_timer/2` (`initnpctimer`) clears `timertick`, sets the timer to 0 and
  starts it; `start_timer/2` (`startnpctimer`), `stop_timer/2`
  (`stopnpctimer`), `set_timer/2` (`setnpctimer`) and `get_timer/1`
  (`getnpctimer`) are the plain ones. A fire sets `timer` to the label's due
  time and `timertick` to the fire's scheduled time (the current time when
  more than a second late, as the reference's timer loop does), arms the next
  label from that scheduled time, and runs the label. After the last label
  the timer keeps ticking (scripts loop by calling `init_timer` again).

  ## Player-attached timers

  The NPC also keeps rAthena's attached player (`nd->u.scr.rid`): the attach
  flag of `initnpctimer`/`startnpctimer` sets it to the script's player, the
  detach flag of `stopnpctimer` clears it, and it otherwise persists. While it
  is set, starting and stopping act on that player's own NPC timer slot
  instead (the player's `sd->npc_timer_id`), which the player's session owns
  (`Unit.Player.Handlers.NpcTimerHandler`); an offline player makes them a
  no-op, as the reference's "Attached player not found". Setting the timer
  always acts on this NPC's own timer. A slot starts from `timer`.

  ## Label runs

  A label run is the reference's `run_script` call around a fired label: it
  lasts until the label first stops to wait (a dialog page, a menu, `sleep`,
  `sleep2`) or ends. The running script's process opens it with
  `begin_run/2` and closes it with `end_run/1`; its own timer commands see
  the run's view meanwhile, and every other process sees the real state:

  - a run of this NPC's own timer sees no attached player, as
    `npc_timerevent` clears `rid` for it.
  - a run of a player's slot (or of `OnTimerQuit` on logout) sees that
    player attached, `timer` at the label's time and `timertick` at the
    run's start, as `npc_timerevent` and `npc_timerevent_quit` swap them in.

  What the run writes to its view is dropped when it closes, as the
  reference restores the swapped fields after `run_script`; what it does to
  the armed fire and to player slots stays. A quit run of the attached
  player itself also detaches it (`npc_timerevent_quit`). The session
  monitors the run's process, so a run that dies closes too.

  ## Dispatch decoupling

  A fired label invokes the `:on_fire` callback (`(gid, label) -> any()`)
  handed to `start_link/1`, always in a detached task under
  `Aesir.ZoneServer.Npc.InteractionSupervisor` — never inside this process.
  `ensure_started/1` spawns sessions defaulting `:on_fire` to
  `Aesir.ZoneServer.Npc.Events.trigger_timer/2`, the real event dispatcher;
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
  GenServer call; a missing row means the NPC's starting state
  (`Placement.state`, or `Warp.state` for a warp portal: none, the usual case,
  is enabled, not hidden and not cloaked, so visible). The table is owned by
  `Aesir.ZoneServer.Npc.SessionSupervisor`, not by any one session, so it
  survives a session crash. A session clears its own row on init and on
  terminate, so a crashed (and, under the dynamic supervisor, restarted)
  session resets to the starting state.

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

  ## Warp portals

  A warp portal (`Npc.Warp`) has the same three flags, keyed by its
  `Warp.Registry.entity_id/1`, as the reference keeps them on every NPC: its
  starting state is its `warp(<STATE>)` flag, a flip broadcasts its spawn or
  vanish, and enabling, unhiding or uncloaking it re-runs the touch check of
  the players standing in its area. The reads take the `%Warp{}` itself on
  the per-movement paths, so its starting state needs no lookup by gid.
  """

  use GenServer
  use TypedStruct

  require Logger

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
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

  @typedoc """
  A label run's view of the timer fields it swaps (see "Label runs"): the
  attached player, and for a slot or quit run the timer value and tick.
  """
  @type run_view :: %{
          required(:rid) => non_neg_integer() | nil,
          optional(:timer) => integer(),
          optional(:timertick) => integer() | nil
        }

  @typedoc """
  What a label run is about: this NPC's own timer, or `char_id`'s slot (or
  logout) firing the label due at `time_ms`.
  """
  @type run_kind :: :own | {:fire | :quit, non_neg_integer(), integer()}

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

  @typedoc """
  The NPC a flag read is about: its gid, or a warp portal itself, whose
  starting state then needs no lookup.
  """
  @type view_target :: non_neg_integer() | Warp.t()
  @typep start_options :: [gid: non_neg_integer(), on_fire: timer_callback()]

  @typedoc "Per-NPC timer, visibility, and appearance state."
  typedstruct enforce: true do
    field :gid, non_neg_integer()
    field :schedule, [timer_entry()], default: []
    field :pending, [timer_entry()], default: []
    field :timer, integer(), default: 0
    field :timertick, integer() | nil, default: nil
    field :armed, {reference(), integer(), non_neg_integer()} | nil, default: nil
    field :on_fire, timer_callback()
    field :rid, non_neg_integer() | nil, default: nil
    field :runs, %{optional(pid()) => {reference(), run_view()}}, default: %{}
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
  Resets the NPC's timer to 0 and starts it (`initnpctimer`), starting the
  session if needed.

  `attach` is the attach flag's player (`initnpctimer ...,1`), which becomes
  the NPC's attached player first; with an attached player the timer starts
  in that player's slot from 0 (see the moduledoc).
  """
  @spec init_timer(non_neg_integer(), non_neg_integer() | nil) :: :ok
  def init_timer(gid, attach \\ nil) do
    gid |> ensure_started() |> GenServer.call({:init_timer, attach})
  end

  @doc """
  Starts the timer from its stored value (`startnpctimer`), starting the
  session if needed. A timer already armed or ticking is left unchanged.

  `attach` is the attach flag's player (`startnpctimer ...,1`); with an
  attached player the timer resumes in that player's slot instead.
  """
  @spec start_timer(non_neg_integer(), non_neg_integer() | nil) :: :ok
  def start_timer(gid, attach \\ nil) do
    gid |> ensure_started() |> GenServer.call({:start_timer, attach})
  end

  @doc """
  Sets the timer's elapsed milliseconds (`setnpctimer`), starting the session
  if needed. A stopped timer stays stopped at `ms`; a started one restarts
  from it.
  """
  @spec set_timer(non_neg_integer(), integer()) :: :ok
  def set_timer(gid, ms) do
    gid |> ensure_started() |> GenServer.call({:set_timer, ms})
  end

  @doc """
  Stops the timer (`stopnpctimer`): disarms it and freezes its elapsed time.
  With an attached player it cancels that player's slot instead, leaving this
  timer alone.

  `detach?` is `stopnpctimer`'s detach flag: the attached player is cleared
  first, so this NPC's own timer stops. A gid with no running session has
  nothing to stop.
  """
  @spec stop_timer(non_neg_integer(), boolean()) :: :ok
  def stop_timer(gid, detach? \\ false) do
    case whereis(gid) do
      nil -> :ok
      pid -> GenServer.call(pid, {:stop_timer, detach?})
    end
  end

  @doc """
  Returns the NPC timer's elapsed milliseconds (`getnpctimer`); inside a slot
  run, the running slot's time.

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
  Opens a label run for the calling process, starting the session if
  needed: until `end_run/1`, its timer commands on this NPC see the run's
  view (see "Label runs" in the moduledoc).
  """
  @spec begin_run(non_neg_integer(), run_kind()) :: :ok
  def begin_run(gid, kind) do
    gid |> ensure_started() |> GenServer.call({:begin_run, kind})
  end

  @doc """
  Closes the calling process's label run on this NPC, dropping what it wrote
  to its view. Without an open run, or a running session, nothing changes.
  """
  @spec end_run(non_neg_integer()) :: :ok
  def end_run(gid) do
    case whereis(gid) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:end_run, self()})
    end
  end

  @doc """
  Returns the NPC's `OnTimer<ms>` schedule, sorted by due time, or `[]` for a
  gid that does not resolve.
  """
  @spec schedule(non_neg_integer()) :: [timer_entry()]
  def schedule(gid) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {module, _placement}} ->
        module.events()
        |> Enum.flat_map(&parse_on_timer/1)
        |> Enum.sort_by(fn {due_ms, _label} -> due_ms end)

      :error ->
        []
    end
  end

  @doc "Returns the pid of `gid`'s running session, or `nil`."
  @spec whereis(non_neg_integer()) :: pid() | nil
  def whereis(gid) do
    case Registry.lookup(session_registry(), gid) do
      [{pid, _value}] -> pid
      [] -> nil
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

  A gid with no row (no session, or a session that never toggled it) reads
  its placement's starting state, enabled unless it starts `:disabled`.
  """
  @spec enabled?(view_target()) :: boolean()
  def enabled?(target) do
    {enabled?, _hidden?, _cloaked?} = flags(target)
    enabled?
  end

  @doc """
  Reads the NPC's `hidden` flag directly from ETS, no GenServer call.

  A gid with no row reads its placement's starting state, hidden only when
  it starts `:hidden` or `:disabled`.
  """
  @spec hidden?(view_target()) :: boolean()
  def hidden?(target) do
    {_enabled?, hidden?, _cloaked?} = flags(target)
    hidden?
  end

  @doc """
  Reads the NPC's `cloaked` flag directly from ETS, no GenServer call.

  A gid with no row reads its placement's starting state, cloaked only when
  it starts `:cloaked`.
  """
  @spec cloaked?(view_target()) :: boolean()
  def cloaked?(target) do
    {_enabled?, _hidden?, cloaked?} = flags(target)
    cloaked?
  end

  @doc """
  Reads the NPC's effective visibility directly from ETS, no GenServer call:
  visible iff enabled, not hidden and not cloaked.

  A single lookup rather than one per flag, so the per-player movement diff
  pays one ETS read per NPC.
  """
  @spec visible?(view_target()) :: boolean()
  def visible?(target) do
    {enabled?, hidden?, cloaked?} = flags(target)
    enabled? and not hidden? and not cloaked?
  end

  @doc """
  Whether the NPC's OnTouch area can fire, read directly from ETS: enabled and
  not cloaked. `hidden` does not block a touch, as in rAthena's
  `npc_touch_areanpc` (`is_invisible`, `npc_is_cloaked`) and
  `npc_touch_areanpc2` (`is_invisible || option&OPTION_CLOAK`).
  """
  @spec touchable?(view_target()) :: boolean()
  def touchable?(target) do
    {enabled?, _hidden?, cloaked?} = flags(target)
    enabled? and not cloaked?
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

  Accepts `:on_fire` (defaults to `Aesir.ZoneServer.Npc.Events.trigger_timer/2`,
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
    on_fire = Keyword.get(opts, :on_fire, &Events.trigger_timer/2)

    # A supervisor's terminate_child/2 sends an untrapped :shutdown exit
    # signal, which would kill this process before terminate/2 runs. Trapping
    # exits ensures terminate/2 always clears the flags row, whether this
    # session stops gracefully, is torn down by its supervisor, or crashes.
    Process.flag(:trap_exit, true)

    clear_flags(gid)
    clear_display(gid)
    {enabled?, hidden?, cloaked?} = initial_flags(gid)

    state = %__MODULE__{
      gid: gid,
      schedule: schedule(gid),
      on_fire: on_fire,
      enabled?: enabled?,
      hidden?: hidden?,
      cloaked?: cloaked?
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:init_timer, attach}, {caller, _tag}, state) do
    in_run(state, caller, fn state ->
      state
      |> attach_rid(attach)
      |> Map.put(:timertick, nil)
      |> set_tick(0)
      |> timer_start()
    end)
  end

  def handle_call({:start_timer, attach}, {caller, _tag}, state) do
    in_run(state, caller, &(&1 |> attach_rid(attach) |> timer_start()))
  end

  def handle_call({:set_timer, ms}, {caller, _tag}, state) do
    in_run(state, caller, &set_tick(&1, ms))
  end

  def handle_call({:stop_timer, detach?}, {caller, _tag}, state) do
    in_run(state, caller, fn state ->
      state = if detach?, do: %{state | rid: nil}, else: state
      timer_stop(state)
    end)
  end

  def handle_call(:get_timer, {caller, _tag}, state) do
    {:reply, state |> view(caller) |> elapsed(), state}
  end

  def handle_call({:begin_run, kind}, {caller, _tag}, state) do
    state = drop_run(state, caller)
    {view, state} = open_view(kind, state)
    runs = Map.put(state.runs, caller, {Process.monitor(caller), view})
    {:reply, :ok, %{state | runs: runs}}
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

  @impl GenServer
  def handle_cast({:end_run, caller}, state), do: {:noreply, drop_run(state, caller)}

  # Only a fire whose ref still matches the armed one is honored: a fire
  # already in the mailbox when its timer was stopped or reset must be
  # recognizable and dropped rather than relied on to never arrive. The fire
  # writes the real fields, whatever runs are open (`npc_timerevent` with no
  # attached player).
  @impl GenServer
  def handle_info({:timer_fire, ref, label}, %{armed: {ref, deadline, due_ms}} = state) do
    now = now_ms()
    tick = if (now - deadline) in 0..1000, do: deadline, else: now
    state = %{state | timer: due_ms, timertick: tick, armed: nil}

    state =
      case state.pending do
        [] -> state
        [{next_ms, next_label} | rest] -> arm(%{state | pending: rest}, next_ms, next_label, tick)
      end

    dispatch(state.gid, label, state.on_fire)
    {:noreply, state}
  end

  def handle_info({:timer_fire, _ref, _label}, state), do: {:noreply, state}

  def handle_info({:DOWN, mref, :process, caller, _reason}, state) do
    case state.runs do
      %{^caller => {^mref, _view}} -> {:noreply, %{state | runs: Map.delete(state.runs, caller)}}
      _not_a_run -> {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    clear_flags(state.gid)
    clear_display(state.gid)
    :ok
  end

  # Private Functions

  @spec via(non_neg_integer()) :: GenServer.name()
  defp via(gid), do: {:via, Registry, {session_registry(), gid}}

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

  defp attach_rid(state, nil), do: state
  defp attach_rid(state, char_id), do: %{state | rid: char_id}

  # `npc_timerevent_start`: an attached player's slot starts from `timer`;
  # this NPC's own timer arms the first label due after `timer` and ticks,
  # unless already armed or ticking.
  @spec timer_start(t()) :: t()
  defp timer_start(%{rid: nil, armed: nil, timertick: nil} = state) do
    now = now_ms()

    case Enum.filter(state.schedule, fn {due_ms, _label} -> due_ms > state.timer end) do
      [] ->
        %{state | timertick: now}

      [{due_ms, label} | rest] ->
        arm(%{state | timertick: now, pending: rest}, due_ms, label, now)
    end
  end

  defp timer_start(%{rid: nil} = state), do: state

  defp timer_start(%{rid: rid} = state) do
    start_slot(state, rid, state.timer)
    state
  end

  # `npc_timerevent_stop`: an attached player's slot is cancelled; this
  # NPC's own timer disarms, and folds its ticked time into `timer`.
  @spec timer_stop(t()) :: t()
  defp timer_stop(%{rid: nil} = state) do
    state = %{state | armed: nil, pending: []}

    case state.timertick do
      nil -> state
      tick -> %{state | timer: state.timer + now_ms() - tick, timertick: nil}
    end
  end

  defp timer_stop(%{rid: rid} = state) do
    with_player(rid, "npc_timerevent_stop", &PlayerSession.npc_timer_stop/1)
    state
  end

  # `npc_settimerevent_tick`: always this NPC's own timer, whatever player is
  # attached.
  @spec set_tick(t(), integer()) :: t()
  defp set_tick(state, ms) do
    started? = state.armed != nil or state.timertick != nil
    own = %{state | rid: nil}
    own = if started?, do: timer_stop(own), else: own
    own = %{own | timer: ms}
    own = if started?, do: timer_start(own), else: own
    %{own | rid: state.rid}
  end

  # `npc_gettimerevent_tick`.
  @spec elapsed(t()) :: integer()
  defp elapsed(%{timer: timer, timertick: nil}), do: timer
  defp elapsed(%{timer: timer, timertick: tick}), do: timer + now_ms() - tick

  # Arms the fire of the label due at `due_ms`, from the time `from_tick` at
  # which the timer stood at `timer`.
  @spec arm(t(), non_neg_integer(), String.t(), integer()) :: t()
  defp arm(state, due_ms, label, from_tick) do
    ref = make_ref()
    deadline = from_tick + due_ms - state.timer
    Process.send_after(self(), {:timer_fire, ref, label}, max(deadline - now_ms(), 0))
    %{state | armed: {ref, deadline, due_ms}}
  end

  # A command from `caller` runs against its run's view when it has one:
  # the swapped fields are read from and written back to the view, the rest
  # of the state is the real one.
  @spec in_run(t(), pid(), (t() -> t())) :: {:reply, :ok, t()}
  defp in_run(state, caller, fun) do
    case Map.fetch(state.runs, caller) do
      {:ok, {mref, run_view}} ->
        keys = Map.keys(run_view)
        done = state |> Map.merge(run_view) |> fun.()
        runs = Map.put(state.runs, caller, {mref, Map.take(done, keys)})
        {:reply, :ok, %{Map.merge(done, Map.take(state, keys)) | runs: runs}}

      :error ->
        {:reply, :ok, fun.(state)}
    end
  end

  @spec view(t(), pid()) :: t()
  defp view(state, caller) do
    case Map.fetch(state.runs, caller) do
      {:ok, {_mref, run_view}} -> Map.merge(state, run_view)
      :error -> state
    end
  end

  @spec open_view(run_kind(), t()) :: {run_view(), t()}
  defp open_view(:own, state), do: {%{rid: nil}, state}

  defp open_view({kind, char_id, time_ms}, state) do
    run_view = %{rid: char_id, timer: time_ms, timertick: now_ms()}
    state = if kind == :quit and state.rid == char_id, do: %{state | rid: nil}, else: state
    {run_view, state}
  end

  @spec drop_run(t(), pid()) :: t()
  defp drop_run(state, caller) do
    case Map.pop(state.runs, caller) do
      {{mref, _view}, runs} ->
        Process.demonitor(mref, [:flush])
        %{state | runs: runs}

      {nil, _runs} ->
        state
    end
  end

  defp start_slot(state, rid, from_ms) do
    with_player(rid, "npc_timerevent_start", fn pid ->
      PlayerSession.npc_timer_start(pid, state.gid, from_ms)
    end)
  end

  defp with_player(char_id, op, fun) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} -> fun.(pid)
      {:error, :not_found} -> Logger.error("#{op}: Attached player not found!")
    end

    :ok
  end

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

  @typep flags :: {enabled? :: boolean(), hidden? :: boolean(), cloaked? :: boolean()}

  @spec flags(view_target()) :: flags()
  defp flags(%Warp{} = warp) do
    gid = Warp.Registry.entity_id(warp)

    case :ets.lookup(@flags_table, gid) do
      [{^gid, enabled?, hidden?, cloaked?}] -> {enabled?, hidden?, cloaked?}
      [] -> state_flags(warp.state)
    end
  end

  defp flags(gid) do
    case :ets.lookup(@flags_table, gid) do
      [{^gid, enabled?, hidden?, cloaked?}] -> {enabled?, hidden?, cloaked?}
      [] -> initial_flags(gid)
    end
  end

  @spec initial_flags(non_neg_integer()) :: flags()
  defp initial_flags(gid) do
    case resolve(gid) do
      {:npc, {_module, %Placement{state: state}}} -> state_flags(state)
      {:warp, %Warp{state: state}} -> state_flags(state)
      :error -> state_flags(nil)
    end
  end

  # The flags a starting state sets, as the reference applies a script's or a
  # warp's `(<STATE>)` flag at load: disabling also hides, as `disablenpc` does.
  @spec state_flags(Placement.state() | nil) :: flags()
  defp state_flags(:disabled), do: {false, true, false}
  defp state_flags(:hidden), do: {true, true, false}
  defp state_flags(:cloaked), do: {true, false, true}
  defp state_flags(nil), do: {true, false, false}

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
    case resolve(gid) do
      {:npc, {_module, %Placement{trigger: {xs, ys}} = placement}} ->
        recheck_area(placement.map, placement.x, placement.y, xs, ys)

      {:warp, %Warp{} = warp} ->
        recheck_area(warp.map, warp.x, warp.y, warp.xs, warp.ys)

      _no_area ->
        :ok
    end
  end

  defp recheck_area(map, x, y, xs, ys) do
    map
    |> SpatialIndex.get_players_in_area(x - xs, y - ys, x + xs, y + ys)
    |> Enum.each(&recheck_player_touch/1)
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
    case resolve(gid) do
      {:npc, {_module, placement} = entry} ->
        case NpcPackets.spawn_packet(entry) do
          :invisible -> :ok
          packet -> broadcast_to_range(placement, packet)
        end

      {:warp, %Warp{} = warp} ->
        broadcast_to_range(warp, NpcPackets.warp_spawn_packet(warp))

      :error ->
        :ok
    end
  end

  @spec broadcast_vanish(non_neg_integer()) :: :ok
  defp broadcast_vanish(gid) do
    case resolve(gid) do
      {:npc, {_module, placement}} -> broadcast_to_range(placement, NpcPackets.vanish_packet(gid))
      {:warp, %Warp{} = warp} -> broadcast_to_range(warp, NpcPackets.vanish_packet(gid))
      :error -> :ok
    end
  end

  @spec broadcast_to_range(Placement.t() | Warp.t(), struct()) :: :ok
  defp broadcast_to_range(%Placement{map: nil}, _packet), do: :ok

  defp broadcast_to_range(%{map: map, x: x, y: y}, packet) do
    Broadcast.to_in_range(map, x, y, Config.view_range(), packet)
  end

  # A gid is a script placement's or, failing that, a warp portal's.
  @spec resolve(non_neg_integer()) :: {:npc, NpcRegistry.entry()} | {:warp, Warp.t()} | :error
  defp resolve(gid) do
    with :error <- NpcRegistry.module_for_unit(gid),
         :error <- Warps.fetch(gid) do
      :error
    else
      {:ok, %Warp{} = warp} -> {:warp, warp}
      {:ok, entry} -> {:npc, entry}
    end
  end
end
