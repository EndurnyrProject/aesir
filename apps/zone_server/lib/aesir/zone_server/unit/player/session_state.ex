defmodule Aesir.ZoneServer.Unit.Player.SessionState do
  @moduledoc """
  The `PlayerSession` GenServer state: the authoritative `PlayerState` game
  state plus the process-level bookkeeping the session needs but the game state
  must not carry (connection wiring, the single-dialog interaction lock, and the
  pending skill-menu/party/guild invite slots).

  All handlers thread this struct as their session state. Every field except the
  two enforced ones is nilable and defaults to `nil`; handlers set and clear the
  optional slots with struct updates rather than dynamic map keys.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "The pending NPC-dialog interaction lock: `{interaction_pid, monitor_ref, npc_gid}`."
  @type interaction_lock :: {pid(), reference(), non_neg_integer()}

  typedstruct do
    field :game_state, PlayerState.t(), enforce: true
    field :connection_pid, pid(), enforce: true
    field :connection_monitor_ref, reference() | nil, default: nil
    field :client_capabilities, [atom()], default: []
    field :interaction_lock, interaction_lock() | nil, default: nil
    field :pending_skill_menu, map() | nil, default: nil
    field :deferred_skill_result, map() | nil, default: nil
    field :pending_party_invite, map() | nil, default: nil
    field :pending_guild_invite, map() | nil, default: nil
  end
end
