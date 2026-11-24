defmodule Aesir.ZoneServer.Script.Ctx do
  @moduledoc """
  Shared script execution context threaded through every item/NPC DSL call.

  Carries the player identity, live game state, the connection process, a source
  tag identifying what triggered the script, a `status` that is `{:error, reason}`
  once a command ended the script (`halt/2`), and the `failures` of commands that
  failed without ending it (`fail/3`).

  For NPC and item-menu interactions it additionally carries the running process
  (`interaction_pid`), the player session process (`session_pid` — the
  single-writer of `PlayerState` that state-mutating DSL primitives route their
  `{:script_apply, op}` calls to), the dialog correlation id the client
  echoes (`npc_gid` — stamped on outgoing `NpcDialog` frames and matched against
  incoming `NpcInteract`), `page` (the accumulated `mes/2` lines awaiting a
  flush at the next dialog suspension point), and `session_ref`, the monitor
  the interaction holds on its session so a blocking primitive can exit cleanly
  if the session dies.

  Ordinary item scripts run inside the owning session. Their `session_state`
  carries that session through inline operations without calling its own mailbox;
  `game_state` remains the current script snapshot, and the two meet only in
  `update_session/2`. NPC and item-menu contexts
  instead use `session_pid` to call their owning session. Item-menu contexts
  retain their item source but never carry inline `session_state` authority.

  NPC event handlers (`OnInit`/`OnTimer`/`donpcevent`, rAthena semantics) run
  with no player attached: `detached/2` builds a `Ctx` for that case, with
  `session_pid`, `char_id`, `account_id`, `connection_pid`, and `game_state`
  all `nil`. Every command that needs the player guards on this and ends the
  script with `{:error, :no_player}` (or, for `refine/4`, which returns a
  tagged result rather than a `Ctx`, returns `{:error, :no_player}` directly)
  instead of touching a nonexistent session or dereferencing a nonexistent
  game state; reads end it the same way. `attached?/1` tells the two shapes
  apart.

  A detached event run for a monster (`OnTouchNPC`) carries it in
  `attached_unit`: the unit the reference's `st->rid` names, which unit
  commands with id 0 (`unitwarp`) target. Player commands still end the script.
  """

  use TypedStruct

  require Logger

  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.ScriptVitals
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @typedoc """
  Tag identifying the script trigger: an item ID, an NPC module atom, or the
  item a Potion Pitcher throws (its heals are read, not applied).
  """
  @type source :: {:item, integer()} | {:npc, atom()} | {:potion_pitch, integer()}

  @typedoc "Pipeline status: `:ok` until `halt/2` is called."
  @type status :: :ok | {:error, term()}

  @typedoc "A command that failed without ending the script: its name and the reason."
  @type failure :: {atom(), term()}

  @typedoc "A Homunculus item effect staged for atomic validation and persistence."
  @type homunculus_effect ::
          :homunculus_evolution | {:homunculus_intimacy, pos_integer()}

  @typedoc """
  An effect an item script cannot apply to `game_state` itself and stages for the
  owning player session to apply after the script finishes, in script order.
  """
  @type session_effect ::
          {:falcon, boolean()}
          | {:homunculus, homunculus_effect()}
          | {:item_skill, integer(), pos_integer(), boolean()}
          | {:produce, integer()}
          | {:item_dialog, atom(), [integer()]}
          | {:script_damage, ScriptVitals.damage()}
          | {:unit_skill_use, integer(), pos_integer()}
          | {:potion_pitch, :flat | :percent, integer(), integer()}
          | {:pet, {:catchpet, pos_integer(), integer()} | {:birthpet}}

  @typedoc """
  The owning session of an inline item script, as the script carries it.

  A script never reads a session field; it hands the session back to the
  session's own handlers through `update_session/2`. The struct is named without
  its field types so that a `t:t/0` mention does not expand a second copy of the
  player state in every DSL spec.
  """
  @type inline_session :: %SessionState{}

  @typedoc "A non-player unit a detached event runs for (the reference's `st->rid`)."
  @type attached_unit :: {:mob, integer()} | nil

  @typedoc "The state carried through a running script, with or without an attached player."
  typedstruct enforce: true do
    field :char_id, integer() | nil
    field :account_id, integer() | nil
    field :connection_pid, pid() | nil
    field :game_state, PlayerState.t() | nil
    field :source, source()
    field :status, status(), default: :ok
    field :interaction_pid, pid() | nil, default: nil
    field :session_pid, pid() | nil, default: nil
    field :session_state, inline_session() | nil, default: nil
    field :npc_gid, non_neg_integer() | nil, default: nil
    field :page, [String.t()], default: []
    field :session_ref, reference() | nil, default: nil
    field :vars, %{optional(atom()) => term()}, default: %{}
    field :session_effects, [session_effect()], default: []
    field :failures, [failure()], default: []
    field :attached_unit, attached_unit(), default: nil
  end

  @doc """
  Builds a `Ctx` from a session-state map and a source tag.

  The session map must contain at least:
  - `:game_state` — a `PlayerState` carrying `character_id` and `account_id`
  - `:connection_pid` — the connection process for this session
  """
  @spec from_session(
          %{
            required(:game_state) => PlayerState.t(),
            required(:connection_pid) => pid(),
            optional(atom()) => term()
          },
          source()
        ) :: t()
  def from_session(%{game_state: %PlayerState{} = ps, connection_pid: pid} = state, source) do
    %__MODULE__{
      char_id: ps.character_id,
      account_id: ps.account_id,
      connection_pid: pid,
      game_state: ps,
      session_state: if(match?({:item, _}, source), do: state),
      source: source
    }
  end

  @doc """
  Runs `fun` on the owning session of an inline item script and folds its
  result back into `ctx`.

  `game_state` is the script's live player state, so the copy inside
  `session_state` is stale as soon as a command changes it. `fun` receives the
  session carrying the current `game_state`, and the session it returns becomes
  the source of both. Nothing else may read `session_state.game_state`.
  """
  @spec update_session(t(), (SessionState.t() -> {reply, SessionState.t()})) :: {reply, t()}
        when reply: var
  def update_session(%__MODULE__{session_state: state} = ctx, fun) do
    {reply, state} = fun.(%{state | game_state: ctx.game_state})
    {reply, %{ctx | game_state: state.game_state, session_state: state}}
  end

  @doc """
  Ends the script: the command did what a buildin that sets the script state
  to END does.

  Throws `{:script_end, ctx}` with `ctx.status` set to `{:error, reason}`, the
  same termination a script's own `close`/`end` uses, so everything after the
  command is skipped. The script's entry point catches it (the NPC interaction,
  the NPC event runner, the compiled item script) and takes the ctx as the
  script's final state. Use `fail/3` for a command that merely failed.
  """
  @spec halt(t(), term()) :: no_return()
  def halt(%__MODULE__{} = ctx, reason) do
    throw({:script_end, %{ctx | status: {:error, reason}}})
  end

  @doc """
  Reports that script command `buildin` failed without changing its status, so
  the script keeps running, as `run_func` does when a buildin returns failure
  without ending the script.

  Only a command that ends the script halts (`halt/2`); every other failure
  logs a warning here and carries on. The failure is also recorded in
  `failures` (newest first) for callers that need to know whether a command
  they issued went through.
  """
  @spec fail(t(), atom(), term()) :: t()
  def fail(%__MODULE__{} = ctx, buildin, reason) do
    Logger.warning("script command #{buildin} returned failure: #{inspect(reason)}")
    %{ctx | failures: [{buildin, reason} | ctx.failures]}
  end

  @doc """
  Builds a detached `Ctx` for an NPC event handler with no player attached
  (rAthena `OnInit`/`OnTimer`/`donpcevent` semantics).

  `module` is the NPC module the event fires on; `npc_gid` is the spawned
  instance's synthetic unit id. `session_pid`, `char_id`, `account_id`,
  `connection_pid`, and `game_state` are all `nil` — every player-touching DSL
  primitive guards on this and halts with `{:error, :no_player}` instead of
  running.
  """
  @spec detached(module(), non_neg_integer()) :: t()
  def detached(module, npc_gid) do
    %__MODULE__{
      char_id: nil,
      account_id: nil,
      connection_pid: nil,
      game_state: nil,
      source: {:npc, module.npc_id()},
      npc_gid: npc_gid
    }
  end

  @doc """
  Whether `ctx` has a player attached.

  `false` for a `detached/2` context (no session, no `game_state`); `true` for
  a `from_session/2` context.

  Keys on `game_state`, not `session_pid`: item scripts run inside the
  owning session and carry `session_state` instead of calling its mailbox.
  """
  @spec attached?(t()) :: boolean()
  def attached?(%__MODULE__{game_state: nil}), do: false
  def attached?(%__MODULE__{}), do: true
end
