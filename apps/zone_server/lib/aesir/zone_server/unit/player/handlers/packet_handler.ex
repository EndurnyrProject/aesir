defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler do
  @moduledoc """
  Handles incoming packet processing for player sessions.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.CartInfo
  alias Aesir.Net.CartItemAdded
  alias Aesir.Net.CartItemRemoved
  alias Aesir.Net.CartMountRequest
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.ChatRequest
  alias Aesir.Net.EquipItem
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.InventoryList
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MoveFromCartRequest
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveToCartRequest
  alias Aesir.Net.NameRequest
  alias Aesir.Net.NameResponse
  alias Aesir.Net.NpcBuyRequest
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.NpcSellRequest
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.PickupItemRequest
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillCast
  alias Aesir.Net.StatUp
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UseItem
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingCloseRequest
  alias Aesir.Net.VendingEntry
  alias Aesir.Net.VendingListRequest
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingPurchaseRequest
  alias Aesir.ZoneServer.Gm.Dispatcher
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.Skills.NvBasic
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shop.Registry, as: ShopRegistry
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Chat constants
  @chat_max_size 255

  @doc """
  Processes a decoded protobuf message routed to the player session.

  Mirrors `handle_packet/3` for the QUIC + protobuf path. Per-feature struct
  clauses are added in their migration slices; everything else falls to a
  logging catch-all.
  """
  def handle_message(message, state)

  # MapLoaded - Player finished loading map (protobuf analogue of CZ_NOTIFY_ACTORINIT)
  def handle_message(%MapLoaded{}, state) do
    handle_map_loaded(state)
  end

  # MoveRequest - Player movement request (protobuf analogue of CZ_REQUEST_MOVE 0x035F)
  def handle_message(%MoveRequest{dest_x: dest_x, dest_y: dest_y}, state) do
    MovementHandler.handle_request_move(state, dest_x, dest_y)
  end

  # ActionRequest - Player action request (protobuf analogue of CZ_REQUEST_ACT 0x0437)
  #
  # NV_BASIC gates (rAthena clif.cpp, gated by basic_skill_check, bypassed by
  # SU_BASIC_SKILL >= 1 which is not yet implemented):
  #   - sit/stand    >= 3  (clif.cpp:11739) -- implemented below
  #   - trade        >= 1  (clif.cpp:12515) -- TODO: no trade handler yet
  #   - emotion      >= 2  (clif.cpp:11636) -- TODO: no emotion handler yet
  #   - chat room    >= 4  (clif.cpp:12378) -- TODO: no chat-room creation yet
  #   - party create >= 7  (clif.cpp:13806) -- TODO: no party handler yet
  def handle_message(%ActionRequest{target_id: target_id, action: action}, state) do
    case action do
      action when action in [0, 7] ->
        GenServer.cast(self(), {:request_attack, target_id, action})

      2 ->
        # NV_BASIC >= 3 gate (rAthena clif.cpp:11739, gated by basic_skill_check).
        # TODO: also bypass when SU_BASIC_SKILL >= 1 is implemented.
        case nv_basic_gate(state, :sit) do
          :ok -> Logger.debug("Player sitting down")
          {:error, _} -> Logger.warning("Player blocked from sitting: NV_BASIC level too low")
        end

      3 ->
        # Standing up is gated the same as sitting in rAthena (DMG_SIT_DOWN path
        # checks NV_BASIC < 3); a player who can't sit can't stand either.
        case nv_basic_gate(state, :sit) do
          :ok -> Logger.debug("Player standing up")
          {:error, _} -> Logger.warning("Player blocked from standing: NV_BASIC level too low")
        end

      _ ->
        Logger.warning("Unknown action type in ActionRequest: #{action}")
    end

    {:noreply, state}
  end

  # SkillCast - Player casts a targeted skill (protobuf analogue of CZ_USE_SKILL 0x0113)
  def handle_message(%SkillCast{skill_id: skill_id, level: level, target_id: target_id}, state) do
    GenServer.cast(self(), {:use_skill, skill_id, level, target_id})
    {:noreply, state}
  end

  # GroundSkillCast - Player casts a ground-targeted skill (protobuf analogue of
  # CZ_USE_SKILL_TOGROUND 0x0AF4)
  def handle_message(%GroundSkillCast{skill_id: skill_id, level: level, x: x, y: y}, state) do
    GenServer.cast(self(), {:use_skill_ground, skill_id, level, x, y})
    {:noreply, state}
  end

  # LearnSkill - Player spends a skill point to learn/raise a skill (protobuf
  # analogue of CZ_UPGRADE_SKILLLEVEL 0x0112)
  def handle_message(%LearnSkill{skill_id: skill_id}, state) do
    GenServer.cast(self(), {:learn_skill, skill_id})
    {:noreply, state}
  end

  # EquipItem - Player equips an item (protobuf analogue of CZ_REQ_WEAR_EQUIP 0x0998).
  # `index` is the client index (server index + 2); the session subtracts the offset.
  def handle_message(%EquipItem{index: index, position: position}, state) do
    GenServer.cast(self(), {:equip_item, index, position})
    {:noreply, state}
  end

  # UnequipItem - Player unequips an item (protobuf analogue of CZ_REQ_TAKEOFF_EQUIP 0x00AB).
  def handle_message(%UnequipItem{index: index}, state) do
    GenServer.cast(self(), {:unequip_item, index})
    {:noreply, state}
  end

  # UseItem - Player uses a consumable (protobuf analogue of CZ_USE_ITEM 0x0439).
  # `index` is the client index (server index + 2); the handler subtracts the offset.
  def handle_message(%UseItem{index: index}, state) do
    GenServer.cast(self(), {:use_item, index})
    {:noreply, state}
  end

  # CartMountRequest - Player mounts (true) or unmounts (false) the pushcart.
  def handle_message(%CartMountRequest{mount: mount}, state) do
    GenServer.cast(self(), {:cart_mount, mount})
    {:noreply, state}
  end

  # MoveToCartRequest - Player moves an inventory item into the cart. `inventory_index`
  # is the client index (server index + 2); the handler subtracts the offset.
  def handle_message(%MoveToCartRequest{inventory_index: index, amount: amount}, state) do
    GenServer.cast(self(), {:move_to_cart, index, amount})
    {:noreply, state}
  end

  # MoveFromCartRequest - Player moves a cart item back into the inventory.
  # `cart_index` is the client index (server index + 2); the handler subtracts the offset.
  def handle_message(%MoveFromCartRequest{cart_index: index, amount: amount}, state) do
    GenServer.cast(self(), {:move_to_inventory, index, amount})
    {:noreply, state}
  end

  # VendingOpenRequest - Merchant opens a vending shop selling cart items. The
  # wire `VendingEntry` lines are flattened to `{cart_index, amount, price}`
  # tuples the pure `Vending` core consumes.
  def handle_message(%VendingOpenRequest{title: title, entries: entries}, state) do
    lines =
      Enum.map(entries, fn %VendingEntry{cart_index: i, amount: a, price: p} -> {i, a, p} end)

    GenServer.cast(self(), {:vending_open, title, lines})
    {:noreply, state}
  end

  # VendingCloseRequest - Merchant closes its own vending shop.
  def handle_message(%VendingCloseRequest{}, state) do
    GenServer.cast(self(), {:vending_close})
    {:noreply, state}
  end

  # VendingListRequest - Player browses a nearby vendor's shop; the session reads
  # the live shop from the registry and replies with a `VendingList`.
  def handle_message(%VendingListRequest{vendor_unit_id: vendor_unit_id}, state) do
    GenServer.cast(self(), {:vending_list, vendor_unit_id})
    {:noreply, state}
  end

  # VendingPurchaseRequest - Buyer purchases from a vendor. The buy lines are
  # flattened to `{index, amount}` tuples; the seller session is the authority.
  def handle_message(
        %VendingPurchaseRequest{vendor_unit_id: vendor_unit_id, items: items},
        state
      ) do
    buy_lines = Enum.map(items, fn %VendingBuy{index: i, amount: a} -> {i, a} end)
    GenServer.cast(self(), {:vending_purchase_request, vendor_unit_id, buy_lines})
    {:noreply, state}
  end

  # PickupItemRequest - Player requests to pick up a ground item by its ground id.
  def handle_message(%PickupItemRequest{ground_id: ground_id}, state) do
    GenServer.cast(self(), {:pickup_item_request, ground_id})
    {:noreply, state}
  end

  # StatUp - Player spends status points to raise a stat (protobuf analogue of
  # CZ_STATUS_CHANGE 0x00BB).
  def handle_message(%StatUp{stat_id: stat_id, amount: amount}, state) do
    StatAllocationHandler.handle_status_up(stat_id, amount, state)
  end

  # Respawn - Death-menu response: respawn or return to char select (protobuf
  # analogue of CZ_RESTART 0x00B2).
  def handle_message(%Respawn{type: type}, state) do
    HealthHandler.handle_restart(type, state)
  end

  # ChatRequest - Player sends an area chat message (protobuf analogue of
  # CZ_REQUEST_CHAT 0x008C). The client sends "CharName : message"; the prefix
  # and length are validated before the message is echoed to the sender and
  # broadcast to visible players.
  def handle_message(
        %ChatRequest{message: raw_message},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    name_prefix = game_state.character_name <> " : "

    cond do
      byte_size(raw_message) > @chat_max_size ->
        Logger.warning(
          "Player #{game_state.character_id} sent a message exceeding maximum length."
        )

      command = gm_command(raw_message, name_prefix) ->
        Dispatcher.dispatch(command, %{game_state: game_state, connection_pid: connection_pid})

      String.starts_with?(raw_message, name_prefix) ->
        packet = %ChatMessage{gid: game_state.character_id, message: raw_message}
        MessageRouter.send_to(connection_pid, packet)
        Broadcast.to_visible_players(game_state, packet, exclude_id: game_state.character_id)

      true ->
        Logger.warning(
          "Player #{game_state.character_id} sent a malformed chat message (expected '#{name_prefix}'). Message: '#{raw_message}'"
        )
    end

    {:noreply, state}
  end

  # NameRequest - Client requests an entity's name (protobuf analogue of
  # CZ_REQNAME2 0x0368). Collapses the legacy player (ZC_ACK_REQNAMEALL) and
  # non-player (ZC_ACK_REQNAME) replies into one NameResponse: players fill
  # party/guild/position, mobs/NPCs leave them empty.
  def handle_message(
        %NameRequest{entity_id: entity_id},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    cond do
      entity_id == game_state.character_id ->
        MessageRouter.send_to(connection_pid, %NameResponse{
          gid: game_state.character_id,
          name: game_state.character_name
        })

      MapSet.member?(game_state.visible_players, entity_id) ->
        case UnitRegistry.get_player_name(entity_id) do
          {:ok, player_name} ->
            MessageRouter.send_to(connection_pid, %NameResponse{gid: entity_id, name: player_name})

          {:error, :not_found} ->
            Logger.warning(
              "Player #{entity_id} in visible set but not found in registry (lagged client)"
            )
        end

      MapSet.member?(game_state.visible_mobs, entity_id) ->
        case UnitRegistry.get_unit(:mob, entity_id) do
          {:ok, {_module, mob_state, _pid}} ->
            MessageRouter.send_to(connection_pid, %NameResponse{
              gid: entity_id,
              name: mob_state.mob_data.name
            })

          {:error, :not_found} ->
            Logger.warning(
              "Mob #{entity_id} in visible set but not found in registry (lagged client)"
            )
        end

      true ->
        reply_npc_name(connection_pid, entity_id)
    end

    {:noreply, state}
  end

  # NpcTalk - Player clicked an NPC unit (protobuf analogue of CZ_CONTACTNPC
  # 0x0090). Resolves the clicked unit to its bespoke NPC module and starts a
  # supervised, monitored interaction process, storing the lock. One dialog at a
  # time: a click while a lock is held is ignored (matches the client). A click
  # on a gid that resolves to no NPC module is ignored.
  def handle_message(%NpcTalk{}, %{interaction_lock: lock} = state) when not is_nil(lock) do
    {:noreply, state}
  end

  def handle_message(%NpcTalk{npc_id: gid}, %{game_state: game_state} = state) do
    case ShopRegistry.fetch(gid) do
      {:ok, shop} -> NpcShopHandler.open_window(state, shop)
      :error -> talk_to_npc(gid, game_state, state)
    end
  end

  # NpcInteract - Player's response to the pending NpcDialog. Forwarded to the
  # locked interaction process. Dropped when no dialog is active or the
  # response carries a different npc_id than the active interaction.
  def handle_message(
        %NpcInteract{npc_id: gid} = msg,
        %{interaction_lock: {pid, _ref, gid}} = state
      ) do
    send(pid, {:npc_interact, msg})
    {:noreply, state}
  end

  def handle_message(%NpcInteract{}, state) do
    {:noreply, state}
  end

  # NpcBuyRequest - Player buys items from a clicked NPC shop. The buyer is the
  # sole writer, so the handler runs the buy transaction inline in this session.
  def handle_message(%NpcBuyRequest{} = msg, state) do
    NpcShopHandler.buy(state, msg)
  end

  # NpcSellRequest - Player sells items back to a clicked NPC shop. The seller is
  # the sole writer, so the handler runs the sell transaction inline in this session.
  def handle_message(%NpcSellRequest{} = msg, state) do
    NpcShopHandler.sell(state, msg)
  end

  def handle_message(message, state) do
    Logger.warning(
      "Dropping unrecognized inbound message #{inspect(message.__struct__)} in PacketHandler " <>
        "(unhandled client intent or forged authoritative message)"
    )

    {:noreply, state}
  end

  # Reads the player's learned NV_BASIC level and gates the action via
  # `NvBasic.allows_action?/2`. Returns `:ok` when the player lacks a stats
  # struct (e.g. pre-spawn), so an early client action never crashes the session.
  defp nv_basic_gate(
         %{
           game_state: %PlayerState{stats: %Stats{progression: %{learned_skills: learned_skills}}}
         },
         action
       )
       when is_map(learned_skills) do
    NvBasic.allows_action?(learned_skills, action)
  end

  defp nv_basic_gate(_state, _action), do: :ok

  # Resolves entity_id to a static NPC placement and replies with its name.
  # Reached only after the own-char/visible_players/visible_mobs branches
  # decline the id; an id that resolves to no NPC module is ignored.
  defp reply_npc_name(connection_pid, entity_id) do
    case NpcRegistry.module_for_unit(entity_id) do
      {:ok, {_module, placement}} ->
        MessageRouter.send_to(connection_pid, %NameResponse{gid: entity_id, name: placement.name})

      :error ->
        Logger.debug("Ignoring name request for entity #{entity_id} (not in view range)")
    end
  end

  # Resolves the clicked gid to its bespoke NPC module and starts a supervised,
  # monitored interaction process, storing the lock. A gid that resolves to no
  # NPC module is ignored. Reached only after the shop branch declines the gid.
  defp talk_to_npc(gid, game_state, state) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {module, _placement}} ->
        base_ctx =
          Ctx.from_session(
            %{game_state: game_state, connection_pid: state.connection_pid},
            {:npc, module.npc_id()}
          )

        base_ctx = %{base_ctx | npc_gid: gid}
        {:ok, pid} = Interaction.start(self(), module, base_ctx)
        ref = Process.monitor(pid)

        {:noreply, %{state | interaction_lock: {pid, ref, gid}}}

      :error ->
        {:noreply, state}
    end
  end

  # Returns the `@`-prefixed command string when `raw_message` carries the valid
  # name prefix and the remainder begins with `@`; otherwise nil. Keeps the chat
  # `cond` flat instead of nesting a check inside the broadcast branch.
  defp gm_command(raw_message, name_prefix) do
    case String.replace_prefix(raw_message, name_prefix, "") do
      ^raw_message -> nil
      "@" <> _ = command -> command
      _ -> nil
    end
  end

  defp handle_map_loaded(%{game_state: %{pending_map_load: :warp} = game_state} = state) do
    Logger.debug("Player #{game_state.character_id} finished loading warp destination map")

    # The client already holds inventory/skills/stats from the initial load, so
    # a warp only needs to re-enter the player on the destination map.
    send(self(), :respawn_after_warp)

    cleared_game_state = PlayerState.clear_warp_cooldown(game_state)
    maybe_fire_spawn_warp(cleared_game_state)

    {:noreply, %{state | game_state: %{cleared_game_state | pending_map_load: nil}}}
  end

  defp handle_map_loaded(%{connection_pid: connection_pid, game_state: game_state} = state) do
    Logger.debug("Player #{game_state.character_id} finished loading map (LoadEndAck)")

    StatusSync.send_params(connection_pid, %{
      StatusParams.weight() => Weight.current_weight(game_state.inventory),
      StatusParams.max_weight() => Weight.max_weight(game_state.stats)
    })

    StatusSync.send_params(connection_pid, %{
      StatusParams.next_base_exp() => Leveling.next_base_exp(game_state.stats.progression),
      StatusParams.next_job_exp() => Leveling.next_job_exp(game_state.stats.progression),
      StatusParams.skill_point() => game_state.stats.progression.skill_point
    })

    base_stats = game_state.stats.base_stats

    StatusSync.send_params(connection_pid, %{
      StatusParams.status_point() => game_state.stats.progression.status_point,
      StatusParams.ustr() => StatPoint.cost_to_raise(base_stats.str),
      StatusParams.uagi() => StatPoint.cost_to_raise(base_stats.agi),
      StatusParams.uvit() => StatPoint.cost_to_raise(base_stats.vit),
      StatusParams.uint() => StatPoint.cost_to_raise(base_stats.int),
      StatusParams.udex() => StatPoint.cost_to_raise(base_stats.dex),
      StatusParams.uluk() => StatPoint.cost_to_raise(base_stats.luk)
    })

    StatusSync.send_stat_updates(connection_pid, game_state.stats)
    send_inventory_data(connection_pid, game_state.inventory)
    maybe_send_cart_info(connection_pid, game_state)

    skill_list = SkillListView.build(game_state.stats.progression)
    MessageRouter.send_to(connection_pid, skill_list)

    send(self(), :spawn_player)

    cleared_game_state = PlayerState.clear_warp_cooldown(game_state)
    maybe_fire_spawn_warp(cleared_game_state)

    {:noreply, %{state | game_state: cleared_game_state}}
  end

  # On-spawn entry trigger (rAthena `OnTouch` on-spawn): if the spawn cell sits
  # inside a warp's `xs/ys` area, fire the warp. Runs on both the initial-entry
  # and `:warp` branches of `handle_map_loaded/1`. The cooldown is cleared
  # before this check so a warp that triggered the load cycle can't suppress
  # the on-spawn fire. Real warp data doesn't chain, so this won't loop; the
  # per-player cooldown guards same-map re-fire within a map (Task 7).
  @spec maybe_fire_spawn_warp(PlayerState.t()) :: :ok
  defp maybe_fire_spawn_warp(%PlayerState{} = game_state) do
    warps_for_map =
      case Warps.for_map(game_state.map_name) do
        {:ok, list} -> list
        :error -> []
      end

    case Warp.Registry.hit?(warps_for_map, game_state.x, game_state.y) do
      %Warp{} = warp ->
        GenServer.cast(self(), {:warp, warp.to_map, warp.to_x, warp.to_y})

      nil ->
        :ok
    end
  end

  @doc """
  Builds an `ItemAdded` for an item that just entered the inventory.

  Replaces the legacy `ZC_ITEM_PICKUP_ACK` success path: `server_index` carries the
  +2 client offset, `cards` collapses the four card slots, `type`/`look` are resolved
  from the item database and `result` is the success code (0).
  """
  @spec item_added(InventoryItem.t(), non_neg_integer()) :: ItemAdded.t()
  def item_added(%InventoryItem{} = item, server_index) do
    %ItemAdded{
      index: PlayerState.client_index(server_index),
      amount: item.amount,
      nameid: item.nameid,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      location: item.equip,
      type: client_type(item.nameid),
      result: 0,
      expire_time: encode_expire_time(item.expire_time),
      look: item_view(item.nameid)
    }
  end

  @doc """
  Builds an `ItemRemoved` for an item that left (or was reduced in) the inventory.

  Replaces the legacy `ZC_DELETE_ITEM_FROM_BODY`: `server_index` carries the +2 client
  offset and `reason` is the rAthena delete-type code (0 = normal removal).
  """
  @spec item_removed(non_neg_integer(), pos_integer(), non_neg_integer()) :: ItemRemoved.t()
  def item_removed(server_index, amount, reason \\ 0) do
    %ItemRemoved{
      index: PlayerState.client_index(server_index),
      amount: amount,
      reason: reason
    }
  end

  @doc """
  Builds the full `CartInfo` dump for a cart map (sent on mount/login).

  Mirrors `send_inventory_data/2`'s `InventoryList` but for the cart: each slot is
  reused through `to_inventory_item/2`, so cart wire items carry the same +2
  client index offset as inventory items.
  """
  @spec cart_info(%{non_neg_integer() => InventoryItem.t()}) :: CartInfo.t()
  def cart_info(cart) do
    items =
      cart
      |> Enum.sort_by(fn {index, _item} -> index end)
      |> Enum.map(fn {index, item} -> to_inventory_item(index, item) end)

    %CartInfo{items: items}
  end

  @doc """
  Builds a `CartItemAdded` for a cart slot, mirroring `item_added/2`.
  """
  @spec cart_item_added(InventoryItem.t(), non_neg_integer()) :: CartItemAdded.t()
  def cart_item_added(%InventoryItem{} = item, server_index) do
    %CartItemAdded{
      index: PlayerState.client_index(server_index),
      amount: item.amount,
      nameid: item.nameid,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      location: item.equip,
      type: client_type(item.nameid),
      result: 0,
      expire_time: encode_expire_time(item.expire_time),
      look: item_view(item.nameid)
    }
  end

  @doc """
  Builds a `CartItemRemoved` for a cart slot, mirroring `item_removed/3`.
  """
  @spec cart_item_removed(non_neg_integer(), pos_integer(), non_neg_integer()) ::
          CartItemRemoved.t()
  def cart_item_removed(server_index, amount, reason \\ 0) do
    %CartItemRemoved{
      index: PlayerState.client_index(server_index),
      amount: amount,
      reason: reason
    }
  end

  # Collapses the legacy 4-packet inventory dump (ZC_INVENTORY_START/ITEMLIST_NORMAL/
  # ITEMLIST_EQUIP/END) into a single InventoryList on the Bulk channel. Items split
  # by `equip`: 0 -> normal (stackable), >0 -> equip (worn), both sorted by the unified
  # server index so the client index space (+2 offset) stays collision-free.
  defp send_inventory_data(connection_pid, inventory) do
    {equipped, stackable} =
      inventory
      |> Enum.sort_by(fn {index, _item} -> index end)
      |> Enum.split_with(fn {_index, item} -> item.equip > 0 end)

    list = %InventoryList{
      normal: Enum.map(stackable, fn {index, item} -> to_inventory_item(index, item) end),
      equip: Enum.map(equipped, fn {index, item} -> to_inventory_item(index, item) end)
    }

    MessageRouter.send_to(connection_pid, list)
  end

  # Sends the cart dump on map load only for a mounted player; an unmounted
  # player has an empty cart and needs no CartInfo.
  defp maybe_send_cart_info(_connection_pid, %{cart_type: 0}), do: :ok

  defp maybe_send_cart_info(connection_pid, %{cart: cart}) do
    MessageRouter.send_to(connection_pid, cart_info(cart))
  end

  @spec to_inventory_item(non_neg_integer(), InventoryItem.t()) :: Aesir.Net.InventoryItem.t()
  defp to_inventory_item(index, %InventoryItem{} = item) do
    %Aesir.Net.InventoryItem{
      index: PlayerState.client_index(index),
      nameid: item.nameid,
      type: client_type(item.nameid),
      amount: item.amount,
      location: item.equip,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      expire_time: encode_expire_time(item.expire_time),
      bind_on_equip: item.bound,
      favorite: item.favorite == 1,
      look: item_view(item.nameid)
    }
  end

  @spec client_type(integer()) :: non_neg_integer()
  defp client_type(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{type: type}} -> ClientItemType.to_client_type(type)
      {:error, :item_not_found} -> ClientItemType.to_client_type(:etc)
    end
  end

  @spec item_view(integer()) :: integer()
  defp item_view(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      # Weapons carry their sprite as the weapon class (derived from the subtype)
      # unless the item sets an explicit `view` for a unique sprite. Mirrors
      # `Stats.weapon_view/1` so the inventory `look` matches the appearance view.
      {:ok, %{type: :weapon, view: 0, subtype: subtype}} -> WeaponTypes.get_weapon_id(subtype)
      {:ok, %{view: view}} -> view
      {:error, :item_not_found} -> 0
    end
  end

  @spec encode_expire_time(NaiveDateTime.t() | nil) :: non_neg_integer()
  defp encode_expire_time(nil), do: 0

  defp encode_expire_time(datetime) do
    datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end
end
