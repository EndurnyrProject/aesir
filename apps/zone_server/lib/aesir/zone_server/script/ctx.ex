defmodule Aesir.ZoneServer.Script.Ctx do
  @moduledoc """
  Shared script execution context threaded through every item/NPC DSL call.

  Carries the player identity, live game state, the connection process, a source
  tag identifying what triggered the script, and a `status` accumulator used by
  pipeline helpers to short-circuit on error.

  For NPC interactions it additionally carries the running interaction process
  (`interaction_pid`), the player session process (`session_pid` — the
  single-writer of `PlayerState` that state-mutating DSL primitives route their
  `{:script_apply, op}` calls to), the deterministic NPC unit id the client
  knows (`npc_gid` — stamped on outgoing `NpcDialog` frames and matched against
  incoming `NpcInteract`), `page` (the accumulated `mes/2` lines awaiting a
  flush at the next dialog suspension point), and `session_ref`, the monitor
  the interaction holds on its session so a blocking primitive can exit cleanly
  if the session dies.

  NPC event handlers (`OnInit`/`OnTimer`/`donpcevent`, rAthena semantics) run
  with no player attached: `detached/2` builds a `Ctx` for that case, with
  `session_pid`, `char_id`, `account_id`, `connection_pid`, and `game_state`
  all `nil`. Every player-touching DSL effect guards on this — halting the ctx
  with `{:error, :no_player}` (or, for `refine/4`, which returns a tagged
  result rather than a `Ctx`, returning `{:error, :no_player}` directly) —
  instead of touching a nonexistent session or dereferencing a nonexistent
  game state. Pure reads raise `ArgumentError` instead, since they return bare
  values and have no `status` to carry an error. `attached?/1` tells the two
  shapes apart.
  """

  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "Tag identifying the script trigger — either an item ID or an NPC module atom."
  @type source :: {:item, integer()} | {:npc, atom()}

  @typedoc "Pipeline status: `:ok` until `halt/2` is called."
  @type status :: :ok | {:error, term()}

  @typedoc "A Homunculus item effect staged for atomic validation and persistence."
  @type homunculus_effect ::
          :homunculus_evolution | {:homunculus_intimacy, pos_integer()}

  @enforce_keys [:char_id, :account_id, :connection_pid, :game_state, :source]
  defstruct char_id: nil,
            account_id: nil,
            connection_pid: nil,
            game_state: nil,
            source: nil,
            status: :ok,
            interaction_pid: nil,
            session_pid: nil,
            npc_gid: nil,
            page: [],
            session_ref: nil,
            vars: %{},
            homunculus_effects: []

  @type t() :: %__MODULE__{
          char_id: integer() | nil,
          account_id: integer() | nil,
          connection_pid: pid() | nil,
          game_state: PlayerState.t() | nil,
          source: source(),
          status: status(),
          interaction_pid: pid() | nil,
          session_pid: pid() | nil,
          npc_gid: non_neg_integer() | nil,
          page: [String.t()],
          session_ref: reference() | nil,
          vars: map(),
          homunculus_effects: [homunculus_effect()]
        }

  @doc """
  Builds a `Ctx` from a session-state map and a source tag.

  The session map must contain at least:
  - `:game_state` — a `PlayerState` carrying `character_id` and `account_id`
  - `:connection_pid` — the TCP connection process for this session
  """
  @spec from_session(
          %{:game_state => PlayerState.t(), :connection_pid => pid(), optional(any()) => any()},
          source()
        ) :: t()
  def from_session(%{game_state: %PlayerState{} = ps, connection_pid: pid}, source) do
    %__MODULE__{
      char_id: ps.character_id,
      account_id: ps.account_id,
      connection_pid: pid,
      game_state: ps,
      source: source
    }
  end

  @doc """
  Marks the context as halted with the given error reason.

  Further pipeline steps should check `ctx.status` and skip execution when it is
  not `:ok`.
  """
  @spec halt(t(), term()) :: t()
  def halt(%__MODULE__{} = ctx, reason) do
    %{ctx | status: {:error, reason}}
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

  Keys on `game_state`, not `session_pid` — the DSL's `apply_op` seam keys on
  `session_pid` instead, and the two discriminators diverge on purpose for an
  item-triggered ctx: `from_session/2` never sets `session_pid` (item scripts
  run inline on the session, not through a cross-process call), so
  `attached?/1` reports `true` there while an `apply_op`-routed effect
  (`give_item`, `pay_zeny`, ...) still halts `:no_player` if called from an
  item script. That is fine, and strictly better than the prior behavior: a
  `nil` `session_pid` used to `exit(:noproc)` the whole `PlayerSession` on the
  `GenServer.call`; halting the ctx leaves the session alive.
  """
  @spec attached?(t()) :: boolean()
  def attached?(%__MODULE__{game_state: nil}), do: false
  def attached?(%__MODULE__{}), do: true
end
