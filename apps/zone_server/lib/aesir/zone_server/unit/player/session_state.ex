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

  `canlog_at` is the monotonic ms of the player's last combat action (see
  `Aesir.ZoneServer.Unit.Player.Logout`), `nil` before any. `lingering` is the
  token of the pending disconnect linger, `nil` while connected.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingPurchaseResult
  alias Aesir.ZoneServer.Navigation.Session, as: NavigationSession
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  alias __MODULE__.PendingSkillTextInput

  @typedoc "The pending NPC-dialog interaction lock: `{interaction_pid, monitor_ref, npc_gid}`."
  @type interaction_lock :: {pid(), reference(), non_neg_integer()}

  # Synthetic gid stamped on skill-triggered dialogs (AC_MAKINGARROW's crafting
  # menu). Outside every real unit-id range (warps 0x4000_0000.., NPCs
  # 0x5000_0000..0x57FF_FFFF) so it can never collide with a spawned unit; the
  # client only echoes it back on NpcInteract.
  @system_dialog_gid 0x6000_0000

  @enforce_keys [:game_state, :connection_pid]
  defstruct game_state: nil,
            connection_pid: nil,
            connection_monitor_ref: nil,
            applied_equip_statuses: %{},
            applied_card_unequip_effects: %{},
            interaction_lock: nil,
            npc_item_flag: nil,
            work_in_progress: false,
            progress_bar: nil,
            npc_shop: nil,
            vending_setup: nil,
            vending_purchase: nil,
            pending_skill_text_input: nil,
            pending_skill_menu: nil,
            pending_item_skill: nil,
            deferred_skill_result: nil,
            step_action: nil,
            equip_lock_until: nil,
            pending_party_invite: nil,
            pending_trade_invite: nil,
            trade: nil,
            pending_guild_invite: nil,
            pending_alliance_request: nil,
            guild_storage_ctx: nil,
            quest_info_display: %{map: nil, shown: %{}},
            homunculus: nil,
            homunculus_runtime: %Runtime{private_dirty: false},
            navigation: nil,
            canlog_at: nil,
            lingering: nil,
            npc_event_queue: []

  @type t() :: %__MODULE__{
          game_state: PlayerState.t(),
          connection_pid: pid(),
          connection_monitor_ref: reference() | nil,
          applied_equip_statuses: %{atom() => Stats.equip_status()},
          applied_card_unequip_effects: %{Stats.card_source_key() => Stats.card_cleanup()},
          interaction_lock: interaction_lock() | nil,
          npc_item_flag: boolean() | nil,
          work_in_progress: boolean(),
          progress_bar: progress_bar() | nil,
          npc_shop: non_neg_integer() | nil,
          vending_setup:
            %{setup_id: String.t(), level: pos_integer(), sp_spent: non_neg_integer()} | nil,
          vending_purchase: vending_purchase() | nil,
          pending_skill_text_input: PendingSkillTextInput.t() | nil,
          pending_skill_menu: map() | nil,
          pending_item_skill:
            %{
              required(:skill_id) => integer(),
              required(:level) => pos_integer(),
              required(:keep_requirement?) => boolean(),
              optional(:item_index) => non_neg_integer(),
              optional(:item_nameid) => pos_integer()
            }
            | nil,
          deferred_skill_result: map() | nil,
          step_action: step_action() | nil,
          equip_lock_until: integer() | nil,
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
          pending_alliance_request: map() | nil,
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
          navigation: NavigationSession.t() | nil,
          canlog_at: integer() | nil,
          lingering: reference() | nil,
          npc_event_queue: [{non_neg_integer(), String.t()}]
        }

  @typedoc """
  The buyer's latest vending checkout: its request ID and canonical payload
  (`{vendor_unit_id, shop_id, items}`), the result once settled (`nil` while in
  flight), and the monitor on an invited seller session while it settles.
  """
  @type vending_purchase :: %{
          request_id: pos_integer(),
          payload: {non_neg_integer(), String.t(), [VendingBuy.t()]},
          result: VendingPurchaseResult.t() | nil,
          monitor: reference() | nil
        }

  @typedoc """
  A skill use remembered while the player walks, tried again half a step after
  each cell the walk enters: the skill, its level, the target it was aimed at,
  the attack target to resume, the map it was made on and the pending retry.
  """
  @type step_action :: %{
          skill_id: integer(),
          level: pos_integer(),
          target: term(),
          combat_target_id: integer() | nil,
          map_name: String.t(),
          timer: reference() | nil
        }

  @typedoc "A script's progress bar over the player: its NPC and when it fills (monotonic ms)."
  @type progress_bar :: %{npc_gid: non_neg_integer(), deadline: integer()}

  @spec interaction_blocked?(map()) :: boolean()
  def interaction_blocked?(state) do
    not is_nil(Map.get(state, :interaction_lock)) or
      not is_nil(Map.get(state, :pending_skill_text_input))
  end

  @doc """
  The NPC gid of a skill-staged dialog (Arrow Crafting's list). Such a dialog
  holds the interaction lock but is the skill's menu, not an NPC script.
  """
  @spec system_dialog_gid() :: non_neg_integer()
  def system_dialog_gid, do: @system_dialog_gid

  @doc """
  Whether an NPC script holds the player in a dialog. A skill-staged dialog is
  the skill's menu and does not count.
  """
  @spec npc_dialog?(map()) :: boolean()
  def npc_dialog?(state) do
    case Map.get(state, :interaction_lock) do
      {_pid, _ref, @system_dialog_gid} -> false
      nil -> false
      _lock -> true
    end
  end

  @doc """
  Holds the player in the NPC script dialog `lock`. The script starts with the
  mode's default item-use flag, whatever an earlier script set.
  """
  @spec hold_npc_dialog(map(), interaction_lock()) :: map()
  def hold_npc_dialog(state, lock),
    do: Map.merge(state, %{interaction_lock: lock, npc_item_flag: nil})

  @doc "Whether a skill-staged dialog (the skill's own menu) is open."
  @spec system_dialog?(map()) :: boolean()
  def system_dialog?(state),
    do: match?({_pid, _ref, @system_dialog_gid}, Map.get(state, :interaction_lock))

  @doc """
  Whether the NPC script holding the player lets it use items and self skills.
  Each script starts with the mode's default, allowed in pre-renewal and
  refused in renewal, until it enables or disables item use itself.
  """
  @spec npc_item_flag?(map()) :: boolean()
  def npc_item_flag?(state) do
    case Map.get(state, :npc_item_flag) do
      nil -> GameMode.mode() == :pre_renewal
      flag -> flag
    end
  end

  @doc """
  Whether a work in progress blocks the player's skill, item and NPC requests:
  a script's progress bar or a labelled skill menu still awaiting its answer.
  """
  @spec work_in_progress?(map()) :: boolean()
  def work_in_progress?(state),
    do: Map.get(state, :work_in_progress, false) or menu_work_in_progress?(state)

  @doc "Starts a script's progress bar for `npc_gid`, filling `seconds` from now, and holds the work flag."
  @spec hold_progress_bar(map(), non_neg_integer(), non_neg_integer()) :: map()
  def hold_progress_bar(state, npc_gid, seconds) do
    deadline = System.monotonic_time(:millisecond) + seconds * 1000

    Map.merge(state, %{
      progress_bar: %{npc_gid: npc_gid, deadline: deadline},
      work_in_progress: true
    })
  end

  @doc "Ends the progress bar and releases the work flag."
  @spec release_progress_bar(map()) :: map()
  def release_progress_bar(state),
    do: Map.merge(state, %{progress_bar: nil, work_in_progress: false})

  @doc "Whether an NPC shop window is open (its synthetic gid is held)."
  @spec npc_shop_open?(map()) :: boolean()
  def npc_shop_open?(state), do: Map.get(state, :npc_shop) != nil

  @doc "Whether a labelled menu's client skill/NPC work flag remains held."
  @spec menu_work_in_progress?(map()) :: boolean()
  def menu_work_in_progress?(state) do
    case Map.get(state, :pending_skill_menu) do
      %{kind: :OPTIONS} = menu -> Map.get(menu, :work_in_progress?, true)
      _ -> false
    end
  end
end
