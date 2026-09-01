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
  must not carry (connection wiring, owned equip statuses, the single-dialog
  interaction lock, pending invites, and accepted trade handle).

  All handlers thread this struct as their session state. Optional slots default
  to `nil`; equip-status ownership starts empty and `homunculus_runtime` starts as
  a fresh `Runtime`.
  Handlers set and clear optional slots with struct updates rather than dynamic map keys.
  """

  alias Aesir.ZoneServer.Navigation.Session, as: NavigationSession
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  alias __MODULE__.PendingSkillTextInput

  @typedoc "The pending NPC-dialog interaction lock: `{interaction_pid, monitor_ref, npc_gid}`."
  @type interaction_lock :: {pid(), reference(), non_neg_integer()}

  @enforce_keys [:game_state, :connection_pid]
  defstruct game_state: nil,
            connection_pid: nil,
            connection_monitor_ref: nil,
            client_capabilities: [],
            applied_equip_statuses: %{},
            interaction_lock: nil,
            pending_skill_text_input: nil,
            pending_skill_menu: nil,
            deferred_skill_result: nil,
            pending_party_invite: nil,
            pending_trade_invite: nil,
            trade: nil,
            pending_guild_invite: nil,
            guild_storage_ctx: nil,
            quest_info_display: %{map: nil, shown: %{}},
            homunculus: nil,
            homunculus_runtime: %Runtime{private_dirty: false},
            navigation: nil

  @type t() :: %__MODULE__{
          game_state: PlayerState.t(),
          connection_pid: pid(),
          connection_monitor_ref: reference() | nil,
          client_capabilities: [atom()],
          applied_equip_statuses: %{atom() => Stats.equip_status()},
          interaction_lock: interaction_lock() | nil,
          pending_skill_text_input: PendingSkillTextInput.t() | nil,
          pending_skill_menu: map() | nil,
          deferred_skill_result: map() | nil,
          pending_party_invite: map() | nil,
          pending_trade_invite:
            %{
              requester_char_id: integer(),
              requester_pid: pid(),
              requester_name: String.t(),
              expires_at: integer()
            }
            | nil,
          trade:
            %{pid: pid(), monitor: reference(), partner_char_id: integer()}
            | nil,
          pending_guild_invite: map() | nil,
          guild_storage_ctx:
            %{
              guild_id: non_neg_integer(),
              char_id: non_neg_integer(),
              session_pid: pid(),
              capacity: pos_integer()
            }
            | nil,
          quest_info_display: %{
            map: String.t() | nil,
            shown: %{non_neg_integer() => {non_neg_integer(), non_neg_integer()}}
          },
          homunculus: HomunculusState.t() | nil,
          homunculus_runtime: Runtime.t(),
          navigation: NavigationSession.t() | nil
        }

  @spec interaction_blocked?(map()) :: boolean()
  def interaction_blocked?(state) do
    not is_nil(Map.get(state, :interaction_lock)) or
      not is_nil(Map.get(state, :pending_skill_text_input))
  end
end
