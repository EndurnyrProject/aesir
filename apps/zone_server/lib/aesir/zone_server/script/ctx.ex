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
  """

  use TypedStruct

  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "Tag identifying the script trigger — either an item ID or an NPC module atom."
  @type source :: {:item, integer()} | {:npc, atom()}

  @typedoc "Pipeline status: `:ok` until `halt/2` is called."
  @type status :: :ok | {:error, term()}

  typedstruct do
    field :char_id, integer(), enforce: true
    field :account_id, integer(), enforce: true
    field :connection_pid, pid(), enforce: true
    field :game_state, PlayerState.t(), enforce: true
    field :source, source(), enforce: true
    field :status, status(), default: :ok
    field :interaction_pid, pid()
    field :session_pid, pid()
    field :npc_gid, non_neg_integer()
    field :page, [String.t()], default: []
    field :session_ref, reference()
    field :vars, map(), default: %{}
  end

  @doc """
  Builds a `Ctx` from a session-state map and a source tag.

  The session map must contain at least:
  - `:game_state` — a `PlayerState` carrying `character_id` and `account_id`
  - `:connection_pid` — the TCP connection process for this session
  """
  @spec from_session(%{game_state: PlayerState.t(), connection_pid: pid()}, source()) :: t()
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
end
