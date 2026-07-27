defmodule Aesir.ZoneServer.Unit.Player.SessionState.PendingSkillTextInput do
  @moduledoc false

  alias Aesir.ZoneServer.Mmo.Skill.Active

  @enforce_keys [:request_id, :skill_id, :level, :target, :timer_ref]
  defstruct [:request_id, :skill_id, :level, :target, :timer_ref]

  @type t() :: %__MODULE__{
          request_id: non_neg_integer(),
          skill_id: non_neg_integer(),
          level: pos_integer(),
          target: Active.target(),
          timer_ref: reference()
        }
end

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

  alias Aesir.ZoneServer.Unit.Player.PlayerState

  alias __MODULE__.PendingSkillTextInput

  @typedoc "The pending NPC-dialog interaction lock: `{interaction_pid, monitor_ref, npc_gid}`."
  @type interaction_lock :: {pid(), reference(), non_neg_integer()}

  @enforce_keys [:game_state, :connection_pid]
  defstruct game_state: nil,
            connection_pid: nil,
            connection_monitor_ref: nil,
            client_capabilities: [],
            interaction_lock: nil,
            pending_skill_text_input: nil,
            pending_skill_menu: nil,
            deferred_skill_result: nil,
            pending_party_invite: nil,
            pending_guild_invite: nil

  @type t() :: %__MODULE__{
          game_state: PlayerState.t(),
          connection_pid: pid(),
          connection_monitor_ref: reference() | nil,
          client_capabilities: [atom()],
          interaction_lock: interaction_lock() | nil,
          pending_skill_text_input: PendingSkillTextInput.t() | nil,
          pending_skill_menu: map() | nil,
          deferred_skill_result: map() | nil,
          pending_party_invite: map() | nil,
          pending_guild_invite: map() | nil
        }

  @spec interaction_blocked?(map()) :: boolean()
  def interaction_blocked?(state) do
    not is_nil(Map.get(state, :interaction_lock)) or
      not is_nil(Map.get(state, :pending_skill_text_input))
  end
end
