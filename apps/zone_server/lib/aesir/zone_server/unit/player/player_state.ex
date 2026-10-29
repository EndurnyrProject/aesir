defmodule Aesir.ZoneServer.Unit.Player.PlayerState do
  @moduledoc """
  Represents the state of a player in the game world.
  Implements the Entity behaviour for status effect calculations.
  """

  @behaviour Aesir.ZoneServer.Unit

  @doc "Returns the unmodified player cell delay before equipment and status effects."
  @spec base_walk_speed() :: pos_integer()
  def base_walk_speed, do: 150

  import Bitwise

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Race
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @riding_option_bit Option.id(:riding)

  @type direction :: 0..7
  @type movement_state :: :standing | :moving
  @type action_state ::
          :idle
          | :moving
          | :combat_moving
          | :skill_moving
          | :moving_to_item
          | :attacking
          | :casting
          | :sitting
          | :dead
          | :trading

  @typedoc """
  The owner's homunculus as the skill checks of a player's cast read it: its
  lifecycle and HP, stamped by the skill handler before the cast is checked.
  """
  @type homunculus_summary :: %{
          lifecycle: :active | :rested | :dead,
          hp: non_neg_integer(),
          max_hp: non_neg_integer()
        }

  @type t :: %__MODULE__{
          character_id: integer(),
          character_name: String.t(),
          account_id: integer(),
          process_pid: pid() | nil,
          party_id: non_neg_integer(),
          guild_id: non_neg_integer(),
          pvp_point: integer(),
          pvp_won: non_neg_integer(),
          pvp_lost: non_neg_integer(),
          guild_tax: non_neg_integer(),
          waiting_room: non_neg_integer() | nil,
          sex: String.t(),
          hair: integer(),
          hair_color: integer(),
          clothes_color: integer(),
          head_mid: integer(),
          head_bottom: integer(),
          robe: integer(),
          x: integer(),
          y: integer(),
          map_name: String.t(),
          pending_map_load: :login | :warp | nil,
          memo_points: [map()],
          save_map: String.t(),
          save_x: integer(),
          save_y: integer(),
          dir: direction(),
          action_state: action_state(),
          state_context: map(),
          casting: map() | nil,
          movement_state: movement_state(),
          walk_path: list({integer(), integer()}),
          walk_speed: integer(),
          pending_step: HitStop.step(),
          walk_target: {integer(), integer()} | nil,
          movement_intent: :none | :normal | :combat | :skill | :pickup,
          view_range: integer(),
          visible_players: MapSet.t(),
          visible_mobs: MapSet.t(),
          visible_homunculi: MapSet.t(),
          homunculus_summary: homunculus_summary() | nil,
          visible_warps: MapSet.t(),
          visible_npcs: MapSet.t(),
          visible_shops: MapSet.t(),
          visible_items: MapSet.t(),
          visible_skill_units: MapSet.t(),
          last_visibility_cell: {integer(), integer()} | nil,
          inside_npc_areas: MapSet.t(),
          target_id: integer() | nil,
          combat_target_id: integer() | nil,
          combat_action_type: integer() | nil,
          combo: Combo.t(),
          last_target_position: {integer(), integer()} | nil,
          pickup_target_id: integer() | nil,
          last_attack_timestamp: integer(),
          act_delay_until: integer(),
          attack_lock_until: integer(),
          last_warp_at: integer() | nil,
          last_emote_at: integer() | nil,
          deferred_epoch: non_neg_integer(),
          last_song: %{skill_id: integer(), level: pos_integer()} | nil,
          ensemble_partner: integer() | nil,
          plagiarized: %{skill_id: integer(), level: pos_integer()} | nil,
          continuous_attack_timer: reference() | nil,
          pending_forced_movement: ForcedMovement.t() | nil,
          spirit_spheres: SpiritSpheres.t(),
          spirit_spheres_old: non_neg_integer(),
          spirit_sphere_timer: reference() | nil,
          spirit_sphere_timer_plan: %{generation: non_neg_integer(), expires_at: integer()} | nil,
          spirit_sphere_timer_generation: non_neg_integer(),
          spirit_sphere_revision: non_neg_integer(),
          invincible_timer: reference() | nil,
          invincible_generation: non_neg_integer(),
          skill_cooldowns: %{integer() => integer()},
          equip_regen_accumulators: %{{atom(), pos_integer()} => non_neg_integer()},
          stats: PlayerStats.t(),
          vars: %{String.t() => term()},
          temp_vars: %{String.t() => term()},
          zeny: integer(),
          quest_log: %{non_neg_integer() => QuestLog.Entry.t()},
          show_delay: boolean(),
          inventory: %{non_neg_integer() => InventoryItem.t()},
          pending_inventory_persist: [
            {%{non_neg_integer() => InventoryItem.t()}, %{non_neg_integer() => InventoryItem.t()},
             term()}
          ],
          pending_inventory_notify: [tuple()],
          pending_item_add_failures: [atom()],
          cart: %{non_neg_integer() => InventoryItem.t()},
          pending_cart_persist: [
            {%{non_neg_integer() => InventoryItem.t()}, %{non_neg_integer() => InventoryItem.t()},
             term()}
          ],
          pending_cart_notify: [tuple()],
          cart_type: non_neg_integer(),
          storage: nil | %{non_neg_integer() => InventoryItem.t()},
          guild_storage: nil | %{non_neg_integer() => InventoryItem.t()},
          pending_warp: {String.t(), non_neg_integer(), non_neg_integer()} | nil,
          pending_interaction: module() | nil,
          pending_menu_offer: map() | nil,
          pending_vending_setup:
            %{required(:level) => pos_integer(), optional(:sp_spent) => non_neg_integer()} | nil,
          vending_shop: map() | nil,
          pending_production_result: %{success: boolean(), item_id: non_neg_integer()} | nil,
          open_menu_skill_id: non_neg_integer(),
          pending_hp_loss: pos_integer() | nil
        }

  @client_index_offset 2

  @warp_cooldown_ms 500

  defstruct [
    # Character identification
    :character_id,
    :character_name,
    :account_id,
    :process_pid,

    # Appearance (load-once, cosmetic; sourced from the Character at spawn)
    :sex,
    :hair,
    :hair_color,
    :clothes_color,
    :head_mid,
    :head_bottom,
    :robe,

    # Position & Movement
    :x,
    :y,
    :map_name,
    # :login until the client's first MapLoaded ack puts the player on its map,
    # :warp while a cross-map warp waits for the ack, nil while on a map. Picks
    # the map-load branch; an ack while nil is ignored.
    :pending_map_load,

    # Save point — the return-on-death destination (rAthena save_point).
    :save_map,
    :save_x,
    :save_y,
    :dir,

    # Action state machine
    # Represents the primary action state of the player
    :action_state,

    # State context for current action
    # Stores state-specific data like combat intent
    :state_context,

    # Movement state machine
    # :standing | :moving (kept separate for movement mechanics)
    :movement_state,

    # Movement state
    :walk_path,
    :walk_speed,
    :walk_delay_until,
    # The step the walk scheduled last, read by the hit stop (`HitStop`).
    :pending_step,
    # Where a move request made while walking redirects the walk once the
    # pending step lands.
    :walk_target,

    # Movement intent - why are we moving?
    # :none | :normal | :combat | :skill | :pickup
    :movement_intent,

    # Visibility
    :view_range,
    # MapSet of char_ids currently visible
    :visible_players,
    # MapSet of mob_ids currently visible
    :visible_mobs,
    # MapSet of warp entity_ids currently visible (ephemeral, not persisted)
    :visible_warps,
    # MapSet of static NPC entity_ids currently visible (ephemeral, not persisted)
    :visible_npcs,
    # MapSet of static shop entity_ids currently visible (ephemeral, not persisted)
    :visible_shops,
    # MapSet of ground-item ids currently visible (ephemeral, not persisted)
    :visible_items,
    # MapSet of visible skill-unit group ids (ephemeral, not persisted)
    :visible_skill_units,
    # Last grid cell for visibility check
    :last_visibility_cell,

    # Combat state
    :target_id,
    :combat_target_id,
    :combat_action_type,
    :last_target_position,
    :continuous_attack_timer,
    :pending_forced_movement,

    # Move-to-pickup state — the ground item we are walking toward to pick up.
    :pickup_target_id,

    # Character Stats
    :stats,

    # Persistent char variables (jsonb-backed, sourced from Character.vars)
    # and session-life-only temp char vars (never persisted).
    :zeny,
    # Session-owned ordinary Monk combo window.
    visible_homunculi: MapSet.new(),
    homunculus_summary: nil,
    combo: Combo.new(),
    spirit_spheres: SpiritSpheres.new(),
    # The sphere count a skill's cast-begin requirement check recorded for its
    # own damage (Finger Offensive, Asura Strike); kept until the next one.
    spirit_spheres_old: 0,
    spirit_sphere_timer: nil,
    spirit_sphere_timer_plan: nil,
    spirit_sphere_timer_generation: 0,
    spirit_sphere_revision: 0,
    # Post-map-load and revive invincibility (`Unit.Player.Invincibility`).
    invincible_timer: nil,
    invincible_generation: 0,
    memo_points: [],
    vars: %{},
    temp_vars: %{},
    # Quest log keyed by quest id, restored from character_quests on spawn
    # (QuestPersistence.load_on_spawn/1) and never nil.
    quest_log: %{},

    # NPC touch-area (OnTouch) leave/re-enter hysteresis: MapSet of gids whose
    # touch rect currently contains the player's cell. Populated on every cell
    # change (never on standing still); cleared on warp/map change.
    inside_npc_areas: MapSet.new(),

    # Whether act delay and cooldown refusals are reported to the player
    # (`@showdelay`); off by default, ephemeral.
    show_delay: false,

    # Inventory keyed by stable session index
    inventory: %{},
    # Catalyst-consumption deltas staged by a skill cast for the handler to
    # write through, then cleared. Each entry is `{old_inventory, new_inventory,
    # change}` as produced by `Inventory.remove/3`.
    pending_inventory_persist: [],
    # Inventory-add change descriptors staged by a skill cast so the session
    # handler can emit an ItemAdded for each new/affected slot, then clear them.
    pending_inventory_notify: [],
    # Inventory-add refusals staged by a skill or script cast so the session
    # handler can emit one ItemAddFailed per refusal, then clear them.
    pending_item_add_failures: [],
    # Cart keyed by stable session index, mirroring inventory
    cart: %{},
    pending_cart_persist: [],
    pending_cart_notify: [],
    # In-memory copy of character.cart (0 = no cart, 1/2/3 = sprite tier)
    cart_type: 0,
    # In-memory copy of character.option (e_option sprite-state bitmask). The
    # single writer's authoritative value; persisted bits (e.g. :riding) are
    # read-modify-written against it so unrelated bits are never clobbered.
    option: 0,
    # Account storage keyed by stable session index, mirroring inventory/cart;
    # nil means the storage window is closed (nothing loaded for this session).
    storage: nil,
    # Guild storage follows the same window-state convention as account storage.
    guild_storage: nil,
    # Warp directive staged by a skill cast. When non-nil the handler calls
    # WarpHandler.warp/4 after committing SP/cooldowns, then clears this field.
    pending_warp: nil,
    # Dialog directive staged by a skill cast: a module implementing
    # `on_talk/1` (e.g. AC_MAKINGARROW's crafting menu). The handler starts a
    # Script.Interaction for it after the cast commits, then clears this field.
    pending_interaction: nil,
    # SkillMenu offer staged by a skill cast (SA_AUTOSPELL's bolt list). The
    # pending menu itself lives on the session, which owns the connection, so a
    # cast - which only ever sees this state - stages the offer here and the
    # handler opens it after the cast commits, then clears this field.
    pending_menu_offer: nil,
    # Preparation staged by the paid skill; connection-bound grants live on the session.
    pending_vending_setup: nil,
    # The open vending shop (`VendingHandler.shop()`), independent of the action
    # state: the shop stays open through death, respawn and permitted warps and
    # is closed only by the vending lifecycle.
    vending_shop: nil,
    # Production outcome staged by a menu skill for SkillMenuHandler to send.
    pending_production_result: nil,
    # Read-only snapshot of the open skill menu's source skill (0 for none),
    # stamped by SkillHandler before a cast; the session's menu is the authority.
    open_menu_skill_id: 0,
    # Passive HP loss a cast staged (a failed Create Deadly Poison), applied by
    # SkillHandler after the cast commits.
    pending_hp_loss: nil,
    # In-flight timed-cast descriptor (mirrors MobState.casting). Written by
    # transition_to/3 on entering :casting and cleared on leaving it; nil when
    # no cast is in flight. Cast handlers key off this field, not state_context.
    casting: nil,
    skill_cooldowns: %{},
    last_attack_timestamp: 0,
    act_delay_until: 0,
    # A combo window's hold on attacks (monotonic ms, 0 when none).
    attack_lock_until: 0,
    last_warp_at: nil,
    # Flood-control timestamp for emotes (monotonic ms); nil until the first emote.
    last_emote_at: nil,
    deferred_epoch: 0,
    last_song: nil,
    # Character id of the partner found by the last ensemble cast begin; the
    # attempt's completion locks or fatigues that partner without searching again.
    ensemble_partner: nil,
    plagiarized: nil,
    # Per-interval elapsed-time accumulators for periodic equipment HP
    # regen/loss (`bHPRegenRate`/`bHPLossRate`), keyed by `{family, interval_ms}`.
    equip_regen_accumulators: %{},
    # Party membership (0 = none), sourced from the Character at spawn and
    # kept current by Party.Manager pushes (`characters.party_id` is the
    # source of truth; this mirrors it for the session's lifetime).
    party_id: 0,

    # Guild membership (0 = none), sourced from the Character at spawn and
    # kept current by Guild.Manager pushes (`characters.guild_id` is the
    # source of truth; this mirrors it for the session's lifetime).
    guild_id: 0,
    pvp_point: 0,
    pvp_won: 0,
    pvp_lost: 0,
    # Cached guild-position EXP tax %% (0 = untaxed); refreshed by the social
    # handler on guild attach and on guild broadcasts.
    guild_tax: 0,

    # Chat room the player is currently in (its room id: the NPC gid for NPC
    # rooms, an allocated id for player rooms), or nil.
    # Single-writer field: only WaitingRoomHandler mutates it.
    waiting_room: nil,

    # Marriage partner char id (0 = unmarried), sourced from the Character at
    # spawn. Read-only for now (no marriage system); backs the `getpartnerid`
    # script read.
    partner_id: 0
  ]

  @doc """
  Creates a new PlayerState from a Character's last known position.
  """
  def new(%Aesir.Commons.Models.Character{} = character) do
    %__MODULE__{
      character_id: character.id,
      character_name: character.name,
      account_id: character.account_id,
      # Will be set later if needed
      process_pid: nil,
      party_id: character.party_id,
      guild_id: character.guild_id,
      pvp_point: character.pvp_point,
      pvp_won: character.pvp_won,
      pvp_lost: character.pvp_lost,
      partner_id: character.partner_id,
      sex: character.sex,
      hair: character.hair,
      hair_color: character.hair_color,
      clothes_color: character.clothes_color,
      head_mid: character.head_mid,
      head_bottom: character.head_bottom,
      robe: character.robe,
      map_name: character.last_map,
      x: character.last_x,
      y: character.last_y,
      pending_map_load: :login,
      memo_points: character.memo_points || [],
      save_map: character.save_map,
      save_x: character.save_x,
      save_y: character.save_y,
      dir: 0,

      # Action state machine - starts as idle
      action_state: :idle,
      state_context: %{},

      # Movement state machine - starts as standing
      movement_state: :standing,

      # Movement defaults
      walk_path: [],
      walk_speed: base_walk_speed(),
      movement_intent: :none,

      # Visibility defaults
      view_range: Config.view_range(),
      visible_players: MapSet.new(),
      visible_mobs: MapSet.new(),
      visible_homunculi: MapSet.new(),
      visible_warps: MapSet.new(),
      visible_npcs: MapSet.new(),
      visible_shops: MapSet.new(),
      visible_items: MapSet.new(),
      visible_skill_units: MapSet.new(),
      last_visibility_cell: nil,

      # Combat defaults
      target_id: nil,
      combat_target_id: nil,
      combat_action_type: nil,
      last_target_position: nil,
      pickup_target_id: nil,
      last_attack_timestamp: 0,
      act_delay_until: 0,
      attack_lock_until: 0,

      # Character Stats
      stats: PlayerStats.from_character(character),

      # Char variables + economy
      vars: character.vars || %{},
      temp_vars: %{},
      zeny: character.zeny,

      # e_option sprite-state bitmask (persisted; carries the riding bit)
      option: character.option,

      # Inventory (will be loaded separately)
      inventory: %{},

      # Cart (will be loaded separately)
      cart: %{}
    }
  end

  @doc """
  Updates position in the game state.
  """
  def update_position(%__MODULE__{} = state, x, y) do
    %{state | x: x, y: y}
  end

  @doc """
  Relocates the player to a new map and cell as part of a warp.

  Swaps `map_name`/`x`/`y`, drops the now-stale visibility sets (the player is
  leaving every observer behind), clears `inside_npc_areas` (the OnTouch
  leave/re-enter hysteresis is per-map — a warp can't be a re-entry) and resets
  transient movement/combat state so the player lands idle on the destination
  map.

  The player may walk and attack again at once on arrival: the walk delay, the
  last attack's delay and any combo window's hold end, while the after-cast
  skill delay keeps running.

  Drops any in-flight cast: this sets `action_state` directly rather than going
  through `transition_to/3`, so nothing else would clear it, and a Free Cast
  caster warped mid-walk would otherwise land holding a descriptor whose timer
  fires against a stale target — and whose presence blocks every later cast.
  """
  @spec relocate(t(), String.t(), non_neg_integer(), non_neg_integer()) :: t()
  def relocate(%__MODULE__{} = state, map_name, x, y) do
    %{
      state
      | map_name: map_name,
        x: x,
        y: y,
        action_state: :idle,
        casting: nil,
        pending_forced_movement: nil,
        inside_npc_areas: MapSet.new(),
        walk_delay_until: 0,
        last_attack_timestamp: 0,
        attack_lock_until: 0
    }
    |> clear_visibility()
    |> advance_deferred_epoch()
    |> stop_walking()
    |> clear_combat_intent()
    |> clear_pickup_intent()
  end

  defp advance_deferred_epoch(%__MODULE__{deferred_epoch: epoch} = state) do
    %{state | deferred_epoch: epoch + 1}
  end

  @doc "Forgets every visible entity set and the last visibility cell."
  @spec clear_visibility(t()) :: t()
  def clear_visibility(%__MODULE__{} = state) do
    %{
      state
      | visible_players: MapSet.new(),
        visible_mobs: MapSet.new(),
        visible_homunculi: MapSet.new(),
        visible_warps: MapSet.new(),
        visible_npcs: MapSet.new(),
        visible_shops: MapSet.new(),
        visible_items: MapSet.new(),
        visible_skill_units: MapSet.new(),
        last_visibility_cell: nil
    }
  end

  @doc """
  Builds an indexed inventory map from a list of items, assigning contiguous
  indices starting at 0 ordered by the DB `id`.
  """
  @spec from_list([InventoryItem.t()]) :: %{non_neg_integer() => InventoryItem.t()}
  def from_list(items) when is_list(items) do
    items
    |> Enum.sort_by(& &1.id)
    |> Enum.with_index()
    |> Map.new(fn {item, index} -> {index, item} end)
  end

  @doc """
  Returns the inventory items ordered by their session index.
  """
  @spec to_list(%{non_neg_integer() => InventoryItem.t()}) :: [InventoryItem.t()]
  def to_list(inventory) when is_map(inventory) do
    inventory
    |> Enum.sort_by(fn {index, _item} -> index end)
    |> Enum.map(fn {_index, item} -> item end)
  end

  @doc """
  Returns the item at the given session index, or nil when absent.
  """
  @spec get_by_index(%{non_neg_integer() => InventoryItem.t()}, non_neg_integer()) ::
          InventoryItem.t() | nil
  defdelegate get_by_index(inventory, index), to: ItemContainer

  @doc """
  Returns the smallest unused non-negative index in the inventory map.
  """
  @spec lowest_free_index(%{non_neg_integer() => InventoryItem.t()}) :: non_neg_integer()
  defdelegate lowest_free_index(inventory), to: ItemContainer

  @doc """
  Puts an item at the given session index.
  """
  @spec put_item(%{non_neg_integer() => InventoryItem.t()}, non_neg_integer(), InventoryItem.t()) ::
          %{non_neg_integer() => InventoryItem.t()}
  defdelegate put_item(inventory, index, item), to: ItemContainer

  @doc """
  Removes the item at the given session index.
  """
  @spec delete_index(%{non_neg_integer() => InventoryItem.t()}, non_neg_integer()) ::
          %{non_neg_integer() => InventoryItem.t()}
  defdelegate delete_index(inventory, index), to: ItemContainer

  @doc """
  Converts a server-side session index to the client-side index (+2 offset).
  """
  @spec client_index(non_neg_integer()) :: non_neg_integer()
  def client_index(index) when is_integer(index), do: index + @client_index_offset

  @doc """
  Converts a client-side index back to the server-side session index (−2 offset).
  """
  @spec server_index(non_neg_integer()) :: integer()
  def server_index(index) when is_integer(index), do: index - @client_index_offset

  @doc """
  Sets a movement path and starts walking.
  Transitions state to :moving when path is set.
  """
  def set_path(%__MODULE__{} = state, path) when is_list(path) do
    if path != [] do
      %{
        state
        | walk_path: path,
          movement_state: :moving
      }
    else
      %{state | walk_path: path, movement_state: :standing}
    end
  end

  @doc "Whether this player has an open vending shop."
  @spec vending?(t()) :: boolean()
  def vending?(%__MODULE__{vending_shop: shop}), do: shop != nil

  @doc """
  Stops walking and clears the path.
  Transitions state to :standing.
  """
  def stop_walking(%__MODULE__{} = state) do
    %{
      state
      | walk_path: [],
        movement_state: :standing,
        pending_step: nil,
        walk_target: nil
    }
  end

  @spec apply_walk_delay(t(), non_neg_integer(), integer()) :: t()
  def apply_walk_delay(%__MODULE__{} = state, duration, now) do
    %{
      state
      | walk_delay_until: max(active_walk_delay(state.walk_delay_until, now), now + duration)
    }
  end

  @spec walk_delayed?(t(), integer()) :: boolean()
  def walk_delayed?(%__MODULE__{walk_delay_until: nil}, _now), do: false
  def walk_delayed?(%__MODULE__{walk_delay_until: 0}, _now), do: false
  def walk_delayed?(%__MODULE__{walk_delay_until: until}, now), do: until > now

  defp active_walk_delay(nil, now), do: now
  defp active_walk_delay(0, now), do: now
  defp active_walk_delay(until, _now), do: until

  @doc """
  Updates direction based on movement.
  """
  def update_direction(%__MODULE__{} = state, new_dir) when new_dir in 0..7 do
    %{state | dir: new_dir}
  end

  @doc """
  Sets the process PID for this player state.
  """
  def set_process_pid(%__MODULE__{} = state, pid) when is_pid(pid) do
    %{state | process_pid: pid}
  end

  @doc """
  Transitions to a new action state.
  Validates the transition and updates state context as needed.

  When transitioning to `:casting`, `context` carries the cast lifecycle map,
  which is also stored in the dedicated `casting` field (cleared on any
  transition away from `:casting`):

      %{
        skill_id: integer(),
        skill_level: integer(),
        target: term(),
        element: atom(),
        started_at: integer(),
        fixed_until: integer(),
        total_until: integer(),
        timer_ref: reference() | nil,
        token: term(),
        interruptible: boolean()
      }
  """
  @spec transition_to(t(), action_state(), map()) :: {:ok, t()} | {:error, :invalid_transition}
  def transition_to(%__MODULE__{action_state: current} = state, new_state, context \\ %{}) do
    if can_transition?(current, new_state) do
      state = cancel_pending_for_transition(state, new_state)

      updated_state = %{
        state
        | action_state: new_state,
          state_context: context,
          casting: next_casting(state, current, new_state, context)
      }

      updated_state =
        if current != :dead and new_state == :dead,
          do: advance_deferred_epoch(updated_state),
          else: updated_state

      # Handle state-specific setup
      updated_state = handle_state_entry(updated_state, new_state)
      {:ok, updated_state}
    else
      {:error, :invalid_transition}
    end
  end

  # A cast is owned by its own lifecycle, not by `action_state`: Free Cast
  # overlays one on `:moving` and `:attacking`, so a transition is not on its own
  # evidence the cast ended. Entering `:casting` starts one; death ends one; the
  # hard-cancel edge (`:casting -> :idle`, taken by every non-Free-Cast flow)
  # ends one. Every other transition leaves it alone, so an overlaid cast
  # survives arriving at the destination and swinging mid-walk. The cast's own
  # resolution points call `clear_casting/1` explicitly.
  defp next_casting(_state, _current, :casting, context), do: context
  defp next_casting(_state, _current, :dead, _context), do: nil
  defp next_casting(_state, :casting, :idle, _context), do: nil
  defp next_casting(state, _current, _new_state, _context), do: state.casting

  defp cancel_pending_for_transition(state, new_state)
       when new_state in [
              :idle,
              :moving,
              :combat_moving,
              :skill_moving,
              :moving_to_item,
              :casting,
              :dead
            ],
       do: %{state | pending_forced_movement: nil}

  defp cancel_pending_for_transition(state, _new_state), do: state

  @doc "Stages a validated forced-movement directive for post-commit application."
  @spec put_pending_forced_movement(t(), ForcedMovement.t()) :: t()
  def put_pending_forced_movement(%__MODULE__{} = state, %ForcedMovement{} = directive) do
    %{state | pending_forced_movement: directive}
  end

  @doc "Takes and clears the staged forced-movement directive."
  @spec take_pending_forced_movement(t()) :: {ForcedMovement.t() | nil, t()}
  def take_pending_forced_movement(%__MODULE__{} = state) do
    {state.pending_forced_movement, %{state | pending_forced_movement: nil}}
  end

  @doc "Cancels a staged forced-movement directive."
  @spec clear_pending_forced_movement(t()) :: t()
  def clear_pending_forced_movement(%__MODULE__{} = state),
    do: %{state | pending_forced_movement: nil}

  @doc """
  Ends the in-flight cast (mirrors `MobState.clear_casting/1`).

  Called at a cast's resolution points — completion, cancellation, interruption —
  which under Free Cast can land on any action state, so clearing cannot be left
  to a `transition_to/3` edge.
  """
  @spec clear_casting(t()) :: t()
  def clear_casting(%__MODULE__{} = state), do: %{state | casting: nil}

  @doc "Cancels the current Monk combo window."
  @spec cancel_combo(t()) :: t()
  def cancel_combo(%__MODULE__{combo: %Combo{} = combo} = state) do
    %{state | combo: Combo.cancel(combo)}
  end

  def cancel_combo(%__MODULE__{} = state), do: %{state | combo: Combo.new()}

  @doc """
  Sets combat intent for move-to-attack behavior.
  """
  @spec set_combat_intent(t(), integer(), integer(), {integer(), integer()} | nil) :: t()
  def set_combat_intent(%__MODULE__{} = state, target_id, action_type, target_pos \\ nil) do
    %{
      state
      | combat_target_id: target_id,
        combat_action_type: action_type,
        last_target_position: target_pos,
        movement_intent: :combat
    }
  end

  @doc """
  Stores the continuous auto-attack timer reference, cancelling any previously
  scheduled swing so the loop never double-schedules.
  """
  @spec set_continuous_timer(t(), reference()) :: t()
  def set_continuous_timer(%__MODULE__{} = state, timer_ref) when is_reference(timer_ref) do
    cancel_continuous_timer(state.continuous_attack_timer)
    %{state | continuous_attack_timer: timer_ref}
  end

  @doc """
  Clears combat intent, cancelling any pending auto-attack swing so no orphaned
  timer keeps firing after a disengage.
  """
  @spec clear_combat_intent(t()) :: t()
  def clear_combat_intent(%__MODULE__{} = state) do
    cancel_continuous_timer(state.continuous_attack_timer)

    reset_movement_intent(%{
      state
      | combat_target_id: nil,
        combat_action_type: nil,
        last_target_position: nil,
        continuous_attack_timer: nil
    })
  end

  @doc """
  Drops the attack target and its pending swing only, leaving the movement
  intent and every other order as they are (a stop-attacking status).
  """
  @spec stop_attack(t()) :: t()
  def stop_attack(%__MODULE__{} = state) do
    cancel_continuous_timer(state.continuous_attack_timer)

    %{
      state
      | combat_target_id: nil,
        combat_action_type: nil,
        last_target_position: nil,
        continuous_attack_timer: nil
    }
  end

  # Walking continues as a plain walk; standing has no intent left.
  defp reset_movement_intent(%__MODULE__{movement_state: :moving} = state),
    do: %{state | movement_intent: :normal}

  defp reset_movement_intent(%__MODULE__{} = state), do: %{state | movement_intent: :none}

  defp cancel_continuous_timer(nil), do: :ok

  defp cancel_continuous_timer(ref) when is_reference(ref) do
    Process.cancel_timer(ref)
    :ok
  end

  @doc """
  Clears skill-move intent: the pending skill lives in `state_context`, so drop
  it and reset the movement intent (mirrors `clear_combat_intent/1`). Used when a
  manual move interrupts a player walking into range to cast.
  """
  @spec clear_skill_intent(t()) :: t()
  def clear_skill_intent(%__MODULE__{} = state) do
    reset_movement_intent(%{state | state_context: %{}})
  end

  @doc """
  Sets pickup intent for move-to-pickup behavior, recording the ground item the
  player is walking toward.
  """
  @spec set_pickup_intent(t(), integer()) :: t()
  def set_pickup_intent(%__MODULE__{} = state, ground_id) do
    %{state | pickup_target_id: ground_id, movement_intent: :pickup}
  end

  @doc """
  Clears pickup intent.
  """
  @spec clear_pickup_intent(t()) :: t()
  def clear_pickup_intent(%__MODULE__{} = state) do
    reset_movement_intent(%{state | pickup_target_id: nil})
  end

  @doc """
  Checks whether the after-cast act delay has elapsed.

  Mirrors `AttackSpeed.can_attack?/2`: an `act_delay_until` of `0` means no
  delay is pending (always ready); otherwise the given monotonic `now` must
  have reached the deadline.
  """
  @spec act_ready?(t(), integer()) :: boolean()
  def act_ready?(%{act_delay_until: 0}, _now), do: true
  def act_ready?(%{act_delay_until: until}, now), do: now >= until

  @doc """
  Arms the delays an attack or a parry leaves at the monotonic `now`, given the
  player's `attack_delay`: the next attack waits `attack_delay` from `now` and
  skills wait `AttackSpeed.act_delay/2`. Neither shortens a delay already
  running.
  """
  @spec arm_attack_delay(t(), non_neg_integer(), integer()) :: t()
  def arm_attack_delay(%__MODULE__{stats: stats} = state, attack_delay, now) do
    act_until = now + AttackSpeed.act_delay(attack_delay, job_id(stats))

    %{state | last_attack_timestamp: later(state.last_attack_timestamp, now)}
    |> delay_acts_until(act_until)
  end

  @doc """
  Keeps the player from using skills until at least the monotonic `until`; a
  skill delay already running past it is kept.
  """
  @spec delay_acts_until(t(), integer()) :: t()
  def delay_acts_until(%__MODULE__{} = state, until),
    do: %{state | act_delay_until: later(state.act_delay_until, until)}

  @doc """
  Milliseconds until the player may swing again at the monotonic `now`, given
  its `attack_delay`: its last attack's delay and any combo window's hold, 0
  when it may swing now.
  """
  @spec attack_wait(t(), non_neg_integer(), integer()) :: non_neg_integer()
  def attack_wait(%__MODULE__{} = state, attack_delay, now) do
    cadence =
      if state.last_attack_timestamp == 0,
        do: now,
        else: state.last_attack_timestamp + attack_delay

    hold = if state.attack_lock_until == 0, do: now, else: state.attack_lock_until
    max(max(cadence, hold) - now, 0)
  end

  @doc """
  Holds the player's attacks and walking for a combo window that ends at the
  monotonic `until`; neither hold shortens one already running.
  """
  @spec lock_for_combo(t(), integer(), integer()) :: t()
  def lock_for_combo(%__MODULE__{} = state, until, now) do
    %{state | attack_lock_until: later(state.attack_lock_until, until)}
    |> apply_walk_delay(until - now, now)
  end

  # 0 is no timestamp at all; monotonic time may be negative.
  defp later(0, at), do: at
  defp later(current, at), do: max(current, at)

  defp job_id(%{progression: %{job_id: job_id}}), do: job_id
  defp job_id(_stats), do: nil

  @doc """
  Stamps `last_warp_at` with the current monotonic time in milliseconds,
  arming the per-player warp re-trigger cooldown. The timestamp is ephemeral
  and is never persisted.

  The default cooldown window is `@warp_cooldown_ms` (500ms); callers pass it
  to `within_warp_cooldown?/2` so the guard stays co-located with the trigger.
  """
  @spec mark_warp(t()) :: t()
  def mark_warp(%__MODULE__{} = state) do
    %{state | last_warp_at: System.monotonic_time(:millisecond)}
  end

  @doc """
  Returns `true` when a warp fired within the last `cooldown_ms` milliseconds
  (the same-map-destination re-fire guard), `false` when `last_warp_at` is
  `nil` (fresh state) or the window has elapsed.
  """
  @spec within_warp_cooldown?(t()) :: boolean()
  def within_warp_cooldown?(%__MODULE__{} = state),
    do: within_warp_cooldown?(state, @warp_cooldown_ms)

  @spec within_warp_cooldown?(t(), non_neg_integer()) :: boolean()
  def within_warp_cooldown?(%__MODULE__{last_warp_at: nil}, _cooldown_ms), do: false

  def within_warp_cooldown?(%__MODULE__{last_warp_at: last_warp_at}, cooldown_ms) do
    System.monotonic_time(:millisecond) - last_warp_at < cooldown_ms
  end

  @doc """
  Clears the warp re-trigger cooldown (`last_warp_at`).

  Called from `handle_map_loaded/1` on every map load so a warp that triggered
  the load cycle can't suppress the legitimate on-spawn fire on the destination.
  The cooldown only guards against instant re-fire *within* a map, not across
  the map-load boundary.
  """
  @spec clear_warp_cooldown(t()) :: t()
  def clear_warp_cooldown(%__MODULE__{} = state), do: %{state | last_warp_at: nil}

  @doc """
  Checks if a state transition is valid.
  """
  @spec can_transition?(action_state(), action_state()) :: boolean()
  def can_transition?(from, to) do
    cond do
      # Universal rules
      from == to -> true
      to == :dead -> true
      # Dead state rules
      from == :dead -> to == :idle
      # State-specific rules
      true -> valid_state_transition?(from, to)
    end
  end

  defp valid_state_transition?(:idle, to), do: valid_from_idle?(to)
  defp valid_state_transition?(:moving, to), do: valid_from_moving?(to)
  defp valid_state_transition?(:combat_moving, to), do: valid_from_combat_moving?(to)
  defp valid_state_transition?(:skill_moving, to), do: valid_from_skill_moving?(to)
  defp valid_state_transition?(:moving_to_item, to), do: valid_from_moving_to_item?(to)
  defp valid_state_transition?(:attacking, to), do: valid_from_attacking?(to)
  defp valid_state_transition?(:casting, to), do: valid_from_casting?(to)
  defp valid_state_transition?(:sitting, to), do: valid_from_sitting?(to)
  defp valid_state_transition?(:trading, to), do: valid_from_trading?(to)
  defp valid_state_transition?(_, _), do: false

  defp valid_from_idle?(to),
    do:
      to in [
        :moving,
        :combat_moving,
        :skill_moving,
        :moving_to_item,
        :attacking,
        :casting,
        :sitting,
        :trading
      ]

  defp valid_from_moving?(to), do: to in [:idle, :combat_moving, :moving_to_item, :attacking]
  defp valid_from_combat_moving?(to), do: to in [:idle, :attacking, :moving, :moving_to_item]
  defp valid_from_skill_moving?(to), do: to in [:idle, :moving]
  defp valid_from_moving_to_item?(to), do: to in [:idle, :moving, :combat_moving, :attacking]
  # `:casting` is a timed combo's: its attack keeps its target and pending swing
  # under the cast bar.
  defp valid_from_attacking?(to),
    do: to in [:idle, :moving, :combat_moving, :moving_to_item, :casting]

  # `:moving` and `:attacking` are Free Cast's overlay edges: the caster walks or
  # swings and the cast keeps running (see `Mmo.Skills.Sage.SaFreecast`).
  # `MovementHandler`/`CombatActionHandler` only take them for a caster who knows
  # the skill; everyone else is hard-cancelled or refused first.
  defp valid_from_casting?(to), do: to in [:idle, :moving, :attacking]
  defp valid_from_sitting?(to), do: to == :idle
  defp valid_from_trading?(to), do: to == :idle

  # Private helper to handle state entry logic
  defp handle_state_entry(state, :idle), do: clear_combat_intent(state)

  defp handle_state_entry(state, :moving) do
    # Set movement intent to normal if not combat
    if state.movement_intent == :none do
      %{state | movement_intent: :normal}
    else
      state
    end
  end

  defp handle_state_entry(state, :combat_moving) do
    # Ensure movement intent is combat
    %{state | movement_intent: :combat}
  end

  defp handle_state_entry(state, :skill_moving) do
    # Ensure movement intent is skill (walking into range to cast)
    %{state | movement_intent: :skill}
  end

  defp handle_state_entry(state, :moving_to_item) do
    # Ensure movement intent is pickup
    %{state | movement_intent: :pickup}
  end

  defp handle_state_entry(state, _new_state), do: state

  @impl Aesir.ZoneServer.Unit
  def get_unit_id(%__MODULE__{character_id: character_id}), do: character_id

  @impl Aesir.ZoneServer.Unit
  def get_unit_type(%__MODULE__{}), do: :player

  @impl Aesir.ZoneServer.Unit
  def get_process_pid(%__MODULE__{process_pid: pid}), do: pid

  @impl Aesir.ZoneServer.Unit
  def get_race(%__MODULE__{}), do: Race.player_race()

  @impl Aesir.ZoneServer.Unit
  def get_element(%__MODULE__{}), do: {:neutral, 1}

  @impl Aesir.ZoneServer.Unit
  def is_boss?(%__MODULE__{}), do: false

  @impl Aesir.ZoneServer.Unit
  def knockback_immune?(%__MODULE__{stats: stats}) do
    PlayerStats.get_equipment_modifier(stats, :no_knockback) > 0
  end

  @doc """
  Whether this player carries the intravision equipment flag, which lets them
  see units concealed by Hiding/Cloaking/Chase Walk.
  """
  @spec intravision?(t()) :: boolean()
  def intravision?(%__MODULE__{stats: stats}) do
    PlayerStats.get_equipment_modifier(stats, :intravision) > 0
  end

  @impl Aesir.ZoneServer.Unit
  def get_size(%__MODULE__{}), do: :medium

  @impl Aesir.ZoneServer.Unit
  def get_stats(%__MODULE__{stats: stats}) do
    PlayerStats.to_formula_map(stats)
  end

  @impl Aesir.ZoneServer.Unit
  def get_entity_info(%__MODULE__{} = state) do
    Unit.build_entity_info(__MODULE__, state)
    |> Map.put(:entity_type, :player)
    |> Map.put(:equip_modifiers, state.stats.modifiers.equipment)
    |> Map.put(:magic_reduction, PlayerStats.magic_reduction_percent(state.stats))
  end

  @living_actions [
    :idle,
    :moving,
    :combat_moving,
    :skill_moving,
    :moving_to_item,
    :attacking,
    :casting,
    :sitting,
    :trading
  ]

  @impl Aesir.ZoneServer.Unit
  def living?(%__MODULE__{action_state: action_state, stats: %{current_state: %{hp: hp}}})
      when action_state in @living_actions and is_integer(hp) and hp > 0,
      do: true

  def living?(%__MODULE__{}), do: false

  @impl Aesir.ZoneServer.Unit
  def corpse?(%__MODULE__{action_state: :dead, stats: %{current_state: %{hp: 0}}}), do: true
  def corpse?(%__MODULE__{}), do: false

  @impl Aesir.ZoneServer.Unit
  def to_combatant(%__MODULE__{} = state) do
    weapon_type = PlayerStats.weapon_type(state.stats.equipment)

    Combatant.new!(%{
      unit_id: state.character_id,
      unit_type: :player,
      social_root: {:player, state.character_id},
      reward_root: {:player, state.character_id},
      party_id: state.party_id,
      guild_id: state.guild_id,
      base_stats: state.stats.base_stats,
      combat_stats: state.stats.combat_stats,
      max_hp: state.stats.derived_stats.max_hp,
      max_sp: state.stats.derived_stats.max_sp,
      progression: state.stats.progression,
      element: defense_element(state.stats),
      race: get_race(state),
      size: :medium,
      weapon: %{
        type: weapon_type,
        element: weapon_element(state.stats),
        size: :medium
      },
      right_hand: state.stats.right_hand,
      left_hand: state.stats.left_hand,
      attack_range: PlayerStats.attack_range(state.stats),
      attack_delay_ms: AttackSpeed.calculate_delay_from_stats(state.stats),
      amotion: AttackSpeed.amotion_from_stats(state.stats),
      position: {state.x, state.y},
      map_name: state.map_name,
      divine_protection_level: PlayerStats.skill_level(state.stats, 22),
      demon_bane_level: PlayerStats.skill_level(state.stats, 23),
      beast_bane_level: PlayerStats.skill_level(state.stats, 126),
      dragonology_level: PlayerStats.skill_level(state.stats, 284),
      faith_level: PlayerStats.skill_level(state.stats, 248),
      skin_temper_level: PlayerStats.skill_level(state.stats, 109),
      vulture_eye_level: PlayerStats.skill_level(state.stats, 44),
      class: :normal,
      riding: riding?(state.option),
      equip_modifiers: state.stats.modifiers.equipment,
      magic_reduction: PlayerStats.magic_reduction_percent(state.stats),
      equip_autobonuses: state.stats.equip_autobonuses,
      spirit_spheres: held_spirit_spheres(state)
    })
  end

  defp held_spirit_spheres(%{spirit_spheres: %SpiritSpheres{} = spheres}),
    do: SpiritSpheres.count(spheres)

  defp held_spirit_spheres(_state), do: 0

  defp riding?(option) when is_integer(option), do: (option &&& @riding_option_bit) != 0
  defp riding?(_option), do: false

  defp defense_element(%{modifiers: %{status_effects: %{} = status_effects}}) do
    Map.get(status_effects, :element_override, {:neutral, 1})
  end

  defp defense_element(_stats), do: {:neutral, 1}

  # Ammo element wins, then the equipped weapon's own `attack_element`, then the
  # equipment-script `:atk_ele` (`bonus bAtkEle`), then its forged element and
  # the neutral default. A status endow outranks all of them, applied by the
  # damage calculators through the `:attack_element` modifier.
  defp weapon_element(%PlayerStats{} = stats) do
    item_element(stats.equipment.ammo) || item_element(stats.equipment.right_hand) ||
      equip_atk_element(stats) || forged_weapon_element(stats.worn_items) || :neutral
  end

  @spec forged_weapon_element([map()]) :: atom() | nil
  defp forged_weapon_element(worn_items) do
    Enum.find_value(worn_items, fn item ->
      with true <- :right_hand in EquipLocation.bitmask_to_location_atoms(item.equip),
           {:ok, %ItemCraft{kind: :forged, element: element}} when element != :neutral <-
             ItemCraft.from_map(item.craft) do
        element
      else
        _unforged_neutral_or_other_slot -> nil
      end
    end)
  end

  defp item_element(nil), do: nil

  defp item_element(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{attack_element: element}} when is_atom(element) -> element
      _ -> nil
    end
  end

  defp equip_atk_element(%PlayerStats{modifiers: %{equipment: equipment}}) do
    case Map.get(equipment, :atk_ele) do
      element when is_atom(element) -> element
      _ -> nil
    end
  end

  defp equip_atk_element(%PlayerStats{}), do: nil
end
