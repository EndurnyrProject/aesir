defmodule Aesir.ZoneServer.Mmo.Skill.Menu do
  @moduledoc """
  Capability for skills that stage a `SkillMenu` and act on its validated reply.

  The cast writes `PlayerState.pending_menu_offer`. The session sends it after
  committing the cast and retains any server-owned context until the reply.
  Cancel never reaches `on_menu_reply`; an optional cancellation callback may
  perform the skill's close-time reaction. A spent failure retains its returned
  player state while reporting failure, rather than refunding requirements.
  A silent result closes without feedback; a pending result retains the menu
  descriptor after its work lock has been released.
  """

  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "A selection already checked against the pending offer."
  @type selection :: %{id: non_neg_integer(), extras: [non_neg_integer()]}

  @typedoc "Session-owned context, including the original server-written menu."
  @type context :: %{homunculus: struct() | nil, menu: map(), trading?: boolean()}

  @typedoc "A menu outcome; a failed outcome preserves already-spent resources."
  @type result ::
          {:ok, PlayerState.t()}
          | {:error, atom()}
          | {:failed, PlayerState.t(), atom()}
          | {:silent, PlayerState.t()}
          | {:pending, PlayerState.t()}

  @doc "Acts on a validated selection at the level that opened the menu."
  @callback on_menu_reply(PlayerState.t(), selection(), pos_integer()) :: result()

  @doc "Acts on a validated selection with server-owned menu and companion context."
  @callback on_menu_reply(PlayerState.t(), selection(), pos_integer(), context()) :: result()

  @doc "Applies a skill's cancellation reaction without running its effect."
  @callback on_menu_cancel(PlayerState.t()) :: PlayerState.t()

  @optional_callbacks on_menu_reply: 4, on_menu_cancel: 1
end
