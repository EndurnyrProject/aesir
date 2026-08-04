defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler do
  @moduledoc """
  Routes decoded inbound protobuf messages to their feature handlers.

  Pure routing table: every `handle_message/2` clause delegates to a handler
  module inline (the router already runs inside the player session, the single
  writer), so per-packet ordering is strict. Feature logic lives in the sibling
  `Handlers.*` modules; outbound wire builders live in
  `Unit.Player.InventoryView` and friends.
  """

  require Logger

  alias Aesir.Net.ActionRequest
  alias Aesir.Net.CartMountRequest
  alias Aesir.Net.ChatRequest
  alias Aesir.Net.EmoteRequest
  alias Aesir.Net.EquipItem
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.GuildCreateRequest
  alias Aesir.Net.GuildEmblemRequest
  alias Aesir.Net.GuildEmblemUploadRequest
  alias Aesir.Net.GuildExpelRequest
  alias Aesir.Net.GuildInviteRequest
  alias Aesir.Net.GuildInviteResponse
  alias Aesir.Net.GuildLeaveRequest
  alias Aesir.Net.GuildMemberPositionRequest
  alias Aesir.Net.GuildNoticeEditRequest
  alias Aesir.Net.GuildPositionEditRequest
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MountRequest
  alias Aesir.Net.MoveFromCartRequest
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveToCartRequest
  alias Aesir.Net.NameRequest
  alias Aesir.Net.NpcBuyRequest
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.NpcSellRequest
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.PartyCreateRequest
  alias Aesir.Net.PartyInviteRequest
  alias Aesir.Net.PartyInviteResponse
  alias Aesir.Net.PartyKickRequest
  alias Aesir.Net.PartyLeaderRequest
  alias Aesir.Net.PartyLeaveRequest
  alias Aesir.Net.PartyOptionsRequest
  alias Aesir.Net.PickupItemRequest
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Net.SkillTextInputReply
  alias Aesir.Net.StatUp
  alias Aesir.Net.StorageCloseRequest
  alias Aesir.Net.StorageDepositRequest
  alias Aesir.Net.StorageWithdrawRequest
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UseItem
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingCloseRequest
  alias Aesir.Net.VendingEntry
  alias Aesir.Net.VendingListRequest
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingPurchaseRequest
  alias Aesir.ZoneServer.Mmo.Skills.Novice.NvBasic
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ChatHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.EmoteHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MapLoadHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NameHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PartyHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Processes a decoded protobuf message routed to the player session.

  Per-feature struct clauses delegate to their handler modules; everything
  else falls to a logging catch-all.
  """
  def handle_message(message, state)

  # MapLoaded - Player finished loading map (protobuf analogue of CZ_NOTIFY_ACTORINIT)
  def handle_message(%MapLoaded{}, state) do
    MapLoadHandler.handle_map_loaded(state)
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
  #   - trade        >= 1  (clif.cpp:12515) -- NOTE: no trade handler yet
  #   - emotion      >= 2  (clif.cpp:11636) -- NOTE: no emotion handler yet
  #   - chat room    >= 4  (clif.cpp:12378) -- NOTE: no chat-room creation yet
  #   - party create >= 7  (clif.cpp:13806) -- NOTE: no party handler yet
  def handle_message(%ActionRequest{target_id: target_id, action: action}, state)
      when action in [0, 7] do
    CombatActionHandler.handle_attack_request(state, target_id, action)
  end

  # NV_BASIC >= 3 gate (rAthena clif.cpp:11739, gated by basic_skill_check).
  # NOTE: also bypass when SU_BASIC_SKILL >= 1 is implemented.
  def handle_message(%ActionRequest{action: 2}, state) do
    case nv_basic_gate(state, :sit) do
      :ok -> Logger.debug("Player sitting down")
      {:error, _} -> Logger.warning("Player blocked from sitting: NV_BASIC level too low")
    end

    {:noreply, state}
  end

  # Standing up is gated the same as sitting in rAthena (DMG_SIT_DOWN path
  # checks NV_BASIC < 3); a player who can't sit can't stand either.
  def handle_message(%ActionRequest{action: 3}, state) do
    case nv_basic_gate(state, :sit) do
      :ok -> Logger.debug("Player standing up")
      {:error, _} -> Logger.warning("Player blocked from standing: NV_BASIC level too low")
    end

    {:noreply, state}
  end

  def handle_message(%ActionRequest{action: action}, state) do
    Logger.warning("Unknown action type in ActionRequest: #{action}")
    {:noreply, state}
  end

  # SkillCast - Player casts a targeted skill (protobuf analogue of CZ_USE_SKILL 0x0113)
  def handle_message(%SkillCast{skill_id: 231, level: level, target_id: target_id}, state) do
    target = potion_pitcher_target(target_id)
    SkillHandler.handle_use_skill(state, 231, level, target)
  end

  def handle_message(%SkillCast{skill_id: skill_id, level: level, target_id: target_id}, state) do
    SkillHandler.handle_use_skill(state, skill_id, level, target_id)
  end

  # GroundSkillCast - Player casts a ground-targeted skill (protobuf analogue of
  # CZ_USE_SKILL_TOGROUND 0x0AF4)
  def handle_message(%GroundSkillCast{skill_id: skill_id, level: level, x: x, y: y}, state) do
    SkillHandler.handle_use_skill_ground(state, skill_id, level, x, y)
  end

  # SkillTextInputReply - response to a capability-gated staged skill cast.
  def handle_message(%SkillTextInputReply{} = message, state) do
    SkillTextInputHandler.handle_reply(message, state)
  end

  # LearnSkill - Player spends a skill point to learn/raise a skill (protobuf
  # analogue of CZ_UPGRADE_SKILLLEVEL 0x0112)
  def handle_message(%LearnSkill{skill_id: skill_id}, state) do
    SkillLearningHandler.handle_learn_skill(skill_id, state)
  end

  # EquipItem - Player equips an item (protobuf analogue of CZ_REQ_WEAR_EQUIP 0x0998).
  # `index` is the client index (server index + 2); the router subtracts the offset.
  def handle_message(%EquipItem{index: index, position: position}, state) do
    EquipmentHandler.handle_equip(PlayerState.server_index(index), position, state)
  end

  # UnequipItem - Player unequips an item (protobuf analogue of CZ_REQ_TAKEOFF_EQUIP 0x00AB).
  def handle_message(%UnequipItem{index: index}, state) do
    EquipmentHandler.handle_unequip(PlayerState.server_index(index), state)
  end

  # UseItem - Player uses a consumable (protobuf analogue of CZ_USE_ITEM 0x0439).
  # `index` is the client index (server index + 2); the handler subtracts the offset.
  def handle_message(%UseItem{index: index}, state) do
    ItemHandler.handle_use_item(index, state)
  end

  # CartMountRequest - Player mounts (true) or unmounts (false) the pushcart.
  def handle_message(%CartMountRequest{mount: true}, state) do
    CartHandler.mount(state)
  end

  def handle_message(%CartMountRequest{mount: false}, state) do
    CartHandler.unmount(state)
  end

  # MountRequest - Player mounts (true) or dismounts (false) the Peco-Peco.
  def handle_message(%MountRequest{mount: true}, state) do
    MountHandler.mount(state)
  end

  def handle_message(%MountRequest{mount: false}, state) do
    MountHandler.dismount(state)
  end

  # MoveToCartRequest - Player moves an inventory item into the cart. `inventory_index`
  # is the client index (server index + 2); the handler subtracts the offset.
  def handle_message(%MoveToCartRequest{inventory_index: index, amount: amount}, state) do
    CartHandler.move_to_cart(index, amount, state)
  end

  # MoveFromCartRequest - Player moves a cart item back into the inventory.
  # `cart_index` is the client index (server index + 2); the handler subtracts the offset.
  def handle_message(%MoveFromCartRequest{cart_index: index, amount: amount}, state) do
    CartHandler.move_to_inventory(index, amount, state)
  end

  # StorageDepositRequest - Player moves an inventory item into account storage.
  # `inventory_index` is the client index (server index + 2); the handler subtracts the offset.
  def handle_message(%StorageDepositRequest{inventory_index: index, amount: amount}, state) do
    StorageHandler.deposit(index, amount, state)
  end

  # StorageWithdrawRequest - Player moves a storage item back into the inventory.
  # `storage_index` is the client index (server index + 2); the handler subtracts the offset.
  def handle_message(%StorageWithdrawRequest{storage_index: index, amount: amount}, state) do
    StorageHandler.withdraw(index, amount, state)
  end

  # StorageCloseRequest - Player closes the storage window.
  def handle_message(%StorageCloseRequest{}, state) do
    StorageHandler.close(state)
  end

  # VendingOpenRequest - Merchant opens a vending shop selling cart items. The
  # wire `VendingEntry` lines are flattened to `{cart_index, amount, price}`
  # tuples the pure `Vending` core consumes.
  def handle_message(%VendingOpenRequest{title: title, entries: entries}, state) do
    lines =
      Enum.map(entries, fn %VendingEntry{cart_index: i, amount: a, price: p} -> {i, a, p} end)

    VendingHandler.handle_open(state, title, lines)
  end

  # VendingCloseRequest - Merchant closes its own vending shop.
  def handle_message(%VendingCloseRequest{}, state) do
    VendingHandler.handle_close(state)
  end

  # VendingListRequest - Player browses a nearby vendor's shop; the session reads
  # the live shop from the registry and replies with a `VendingList`.
  def handle_message(%VendingListRequest{vendor_unit_id: vendor_unit_id}, state) do
    VendingHandler.handle_list(state, vendor_unit_id)
  end

  # VendingPurchaseRequest - Buyer purchases from a vendor. The buy lines are
  # flattened to `{index, amount}` tuples; the seller session is the authority.
  def handle_message(
        %VendingPurchaseRequest{vendor_unit_id: vendor_unit_id, items: items},
        state
      ) do
    buy_lines = Enum.map(items, fn %VendingBuy{index: i, amount: a} -> {i, a} end)
    VendingHandler.handle_purchase_request(state, vendor_unit_id, buy_lines)
  end

  # PickupItemRequest - Player requests to pick up a ground item by its ground id.
  def handle_message(%PickupItemRequest{ground_id: ground_id}, state) do
    PickupHandler.handle_pickup(ground_id, state)
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
  # CZ_REQUEST_CHAT 0x008C).
  def handle_message(%ChatRequest{message: raw_message}, state) do
    ChatHandler.handle_chat(raw_message, state)
  end

  # EmoteRequest - Player fires an emote bubble (protobuf analogue of
  # CZ_REQ_EMOTION 0x00BF).
  def handle_message(%EmoteRequest{type: type}, state) do
    EmoteHandler.handle_emote(type, state)
  end

  # NameRequest - Client requests an entity's name (protobuf analogue of
  # CZ_REQNAME2 0x0368).
  def handle_message(%NameRequest{entity_id: entity_id}, state) do
    NameHandler.handle_name_request(entity_id, state)
  end

  # PartyCreateRequest - Player creates a new party with themselves as leader.
  def handle_message(%PartyCreateRequest{} = msg, state) do
    PartyHandler.handle_create_request(msg, state)
  end

  # PartyInviteRequest - Leader invites a character to the party by id or name.
  def handle_message(%PartyInviteRequest{} = msg, state) do
    PartyHandler.handle_invite_request(msg, state)
  end

  # PartyInviteResponse - Invitee's accept/decline response to a pending invite.
  def handle_message(%PartyInviteResponse{} = msg, state) do
    PartyHandler.handle_invite_response(msg, state)
  end

  # PartyLeaveRequest - Player leaves their current party (leader leaving disbands it).
  def handle_message(%PartyLeaveRequest{} = msg, state) do
    PartyHandler.handle_leave_request(msg, state)
  end

  # PartyKickRequest - Leader removes a member from the party.
  def handle_message(%PartyKickRequest{} = msg, state) do
    PartyHandler.handle_kick_request(msg, state)
  end

  # PartyOptionsRequest - Leader toggles even-share EXP.
  def handle_message(%PartyOptionsRequest{} = msg, state) do
    PartyHandler.handle_options_request(msg, state)
  end

  # PartyLeaderRequest - Leader transfers leadership to another member.
  def handle_message(%PartyLeaderRequest{} = msg, state) do
    PartyHandler.handle_leader_request(msg, state)
  end

  # GuildCreateRequest - Player creates a guild with themselves as master
  # (consumes one Emperium on success).
  def handle_message(%GuildCreateRequest{} = msg, state) do
    GuildHandler.handle_create_request(msg, state)
  end

  # GuildInviteRequest - An INVITE-holder invites a character to the guild.
  def handle_message(%GuildInviteRequest{} = msg, state) do
    GuildHandler.handle_invite_request(msg, state)
  end

  # GuildInviteResponse - Invitee's accept/decline response to a pending invite.
  def handle_message(%GuildInviteResponse{} = msg, state) do
    GuildHandler.handle_invite_response(msg, state)
  end

  # GuildLeaveRequest - Player leaves their guild (master leaving disbands it).
  def handle_message(%GuildLeaveRequest{} = msg, state) do
    GuildHandler.handle_leave_request(msg, state)
  end

  # GuildExpelRequest - An EXPEL-holder removes a member from the guild.
  def handle_message(%GuildExpelRequest{} = msg, state) do
    GuildHandler.handle_expel_request(msg, state)
  end

  # GuildNoticeEditRequest - A :notice-holder edits the guild notice.
  def handle_message(%GuildNoticeEditRequest{} = msg, state) do
    GuildHandler.handle_notice_edit_request(msg, state)
  end

  # GuildPositionEditRequest - A :positions-holder edits one position slot.
  def handle_message(%GuildPositionEditRequest{} = msg, state) do
    GuildHandler.handle_position_edit_request(msg, state)
  end

  # GuildMemberPositionRequest - Master assigns a member to a position slot.
  def handle_message(%GuildMemberPositionRequest{} = msg, state) do
    GuildHandler.handle_member_position_request(msg, state)
  end

  # GuildEmblemUploadRequest - Master uploads a new 24x24 BMP emblem.
  def handle_message(%GuildEmblemUploadRequest{} = msg, state) do
    GuildHandler.handle_emblem_upload_request(msg, state)
  end

  # GuildEmblemRequest - Client fetches a guild's current emblem blob.
  def handle_message(%GuildEmblemRequest{} = msg, state) do
    GuildHandler.handle_emblem_request(msg, state)
  end

  # NpcTalk - Player clicked an NPC unit (protobuf analogue of CZ_CONTACTNPC 0x0090).
  def handle_message(%NpcTalk{npc_id: gid}, state) do
    NpcInteractionHandler.handle_talk(gid, state)
  end

  # NpcInteract - Player's response to the pending NpcDialog.
  def handle_message(%NpcInteract{} = msg, state) do
    NpcInteractionHandler.handle_interact(msg, state)
  end

  # SkillMenuReply - Player's choice from the pending SkillMenu. Validated
  # against the parked offer; a stale or forged reply is dropped there.
  def handle_message(%SkillMenuReply{} = msg, state) do
    SkillMenuHandler.handle_reply(msg, state)
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

  defp potion_pitcher_target(target_id) do
    case UnitRegistry.get_unit(:homunculus, target_id) do
      {:ok, _entry} -> {:homunculus, target_id}
      {:error, :not_found} -> target_id
    end
  end
end
