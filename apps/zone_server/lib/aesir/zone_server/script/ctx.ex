defmodule Aesir.ZoneServer.Script.Ctx do
  @moduledoc """
  Shared script execution context threaded through every item/NPC DSL call.

  Carries the player identity, live game state, the connection process, a source
  tag identifying what triggered the script, and a `status` accumulator used by
  pipeline helpers to short-circuit on error.
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
