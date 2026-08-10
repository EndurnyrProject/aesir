defmodule Aesir.ZoneServer.Network.MessageRouter do
  @moduledoc """
  Maps every outbound (server -> client) `Aesir.Net.*` zone message to the
  `bevy_quinnet` channel it rides and the `Aesir.Net.Envelope` oneof tag that
  wraps it.

  This is the single seam that keeps the dispatch refactor mechanical: handlers
  build a struct and a lookup here decides reliable-vs-datagram channel and the
  `Envelope` oneof field. The returned `tag` equals the proto oneof field name so
  `Aesir.Commons.Network.QuicConnection.send_response/3` wraps it correctly.

  Routing follows the design Part 2 channel table. Inbound client intent structs
  are intentionally absent: they never pass through `route/1`.
  """

  alias Aesir.Commons.Network.QuinnetCodec

  @doc """
  Returns the `{channel, oneof_tag}` for an outbound zone message struct.

  Raises `FunctionClauseError` for an unmapped struct so a forgotten mapping
  surfaces at development time rather than being silently swallowed.
  """
  @spec route(struct()) :: {QuinnetCodec.channel(), atom()}
  def route(%Aesir.Net.HelloAck{}), do: {:control, :hello_ack}
  def route(%Aesir.Net.EnterAck{}), do: {:control, :enter_ack}
  def route(%Aesir.Net.MapMove{}), do: {:control, :map_move}
  def route(%Aesir.Net.TimeSyncAck{}), do: {:control, :time_sync_ack}

  def route(%Aesir.Net.SelfMove{}), do: {:gameplay, :self_move}
  def route(%Aesir.Net.MoveStop{}), do: {:gameplay, :move_stop}
  def route(%Aesir.Net.DamageDealt{}), do: {:gameplay, :damage_dealt}
  def route(%Aesir.Net.Knockback{}), do: {:gameplay, :knockback}
  def route(%Aesir.Net.SkillCasting{}), do: {:gameplay, :skill_casting}
  def route(%Aesir.Net.SkillEffect{}), do: {:gameplay, :skill_effect}
  def route(%Aesir.Net.SkillDamage{}), do: {:gameplay, :skill_damage}
  def route(%Aesir.Net.CastCancel{}), do: {:gameplay, :cast_cancel}
  def route(%Aesir.Net.SkillCooldown{}), do: {:gameplay, :skill_cooldown}
  def route(%Aesir.Net.SkillCastFailed{}), do: {:gameplay, :skill_cast_failed}
  def route(%Aesir.Net.EquipResult{}), do: {:gameplay, :equip_result}
  def route(%Aesir.Net.UnequipResult{}), do: {:gameplay, :unequip_result}
  def route(%Aesir.Net.ItemAdded{}), do: {:gameplay, :item_added}
  def route(%Aesir.Net.ItemBound{}), do: {:gameplay, :item_bound}
  def route(%Aesir.Net.ItemRemoved{}), do: {:gameplay, :item_removed}
  def route(%Aesir.Net.CartItemAdded{}), do: {:gameplay, :cart_item_added}
  def route(%Aesir.Net.CartItemRemoved{}), do: {:gameplay, :cart_item_removed}
  def route(%Aesir.Net.StatUpResult{}), do: {:gameplay, :stat_up_result}
  def route(%Aesir.Net.LearnSkillResult{}), do: {:gameplay, :learn_skill_result}
  def route(%Aesir.Net.ItemUseResult{}), do: {:gameplay, :item_use_result}
  def route(%Aesir.Net.ParamChange{}), do: {:gameplay, :param_change}
  def route(%Aesir.Net.Resurrect{}), do: {:gameplay, :resurrect}
  def route(%Aesir.Net.VendingSaleReport{}), do: {:gameplay, :vending_sale_report}
  def route(%Aesir.Net.CartMountResult{}), do: {:gameplay, :cart_mount_result}
  def route(%Aesir.Net.MountResult{}), do: {:gameplay, :mount_result}
  def route(%Aesir.Net.VendingOpenResult{}), do: {:gameplay, :vending_open_result}
  def route(%Aesir.Net.NpcShopOpen{}), do: {:gameplay, :npc_shop_open}
  def route(%Aesir.Net.NpcBuyResult{}), do: {:gameplay, :npc_buy_result}
  def route(%Aesir.Net.NpcSellResult{}), do: {:gameplay, :npc_sell_result}
  def route(%Aesir.Net.PartyActionResult{}), do: {:gameplay, :party_action_result}
  def route(%Aesir.Net.PartyInviteNotify{}), do: {:gameplay, :party_invite_notify}
  def route(%Aesir.Net.PartyInfo{}), do: {:gameplay, :party_info}
  def route(%Aesir.Net.PartyMemberUpdate{}), do: {:gameplay, :party_member_update}
  def route(%Aesir.Net.PartyDisbanded{}), do: {:gameplay, :party_disbanded}
  def route(%Aesir.Net.GuildActionResult{}), do: {:gameplay, :guild_action_result}
  def route(%Aesir.Net.GuildInviteNotify{}), do: {:gameplay, :guild_invite_notify}
  def route(%Aesir.Net.GuildInfo{}), do: {:gameplay, :guild_info}
  def route(%Aesir.Net.GuildMemberUpdate{}), do: {:gameplay, :guild_member_update}
  def route(%Aesir.Net.GuildEmblemChanged{}), do: {:gameplay, :guild_emblem_changed}
  def route(%Aesir.Net.GuildEmblemData{}), do: {:gameplay, :guild_emblem_data}
  def route(%Aesir.Net.GuildDisbanded{}), do: {:gameplay, :guild_disbanded}
  def route(%Aesir.Net.StorageItemAdded{}), do: {:gameplay, :storage_item_added}
  def route(%Aesir.Net.StorageItemRemoved{}), do: {:gameplay, :storage_item_removed}
  def route(%Aesir.Net.StorageResult{}), do: {:gameplay, :storage_result}
  def route(%Aesir.Net.QuestAdded{}), do: {:gameplay, :quest_added}
  def route(%Aesir.Net.QuestRemoved{}), do: {:gameplay, :quest_removed}
  def route(%Aesir.Net.QuestStateChanged{}), do: {:gameplay, :quest_state_changed}
  def route(%Aesir.Net.QuestHuntProgress{}), do: {:gameplay, :quest_hunt_progress}
  def route(%Aesir.Net.HomunculusResult{}), do: {:gameplay, :homunculus_result}
  def route(%Aesir.Net.TradeRequestReceived{}), do: {:gameplay, :trade_request_received}
  def route(%Aesir.Net.TradeOpened{}), do: {:gameplay, :trade_opened}
  def route(%Aesir.Net.TradeOfferUpdate{}), do: {:gameplay, :trade_offer_update}
  def route(%Aesir.Net.TradeCompleted{}), do: {:gameplay, :trade_completed}
  def route(%Aesir.Net.TradeCancelled{}), do: {:gameplay, :trade_cancelled}

  def route(%Aesir.Net.UnitSpawn{}), do: {:world, :unit_spawn}
  def route(%Aesir.Net.SpiritSphereUpdate{}), do: {:world, :spirit_sphere_update}
  def route(%Aesir.Net.UnitDespawn{}), do: {:world, :unit_despawn}
  def route(%Aesir.Net.GroundSkill{}), do: {:world, :ground_skill}
  def route(%Aesir.Net.SpriteChange{}), do: {:world, :sprite_change}
  def route(%Aesir.Net.UnitHp{}), do: {:world, :unit_hp}
  def route(%Aesir.Net.NameResponse{}), do: {:world, :name_response}
  def route(%Aesir.Net.ChatMessage{}), do: {:world, :chat_message}
  def route(%Aesir.Net.StatusChange{}), do: {:world, :status_change}
  def route(%Aesir.Net.UnitStateChange{}), do: {:world, :unit_state_change}
  def route(%Aesir.Net.SpecialEffect{}), do: {:world, :special_effect}
  def route(%Aesir.Net.Viewpoint{}), do: {:world, :viewpoint}
  def route(%Aesir.Net.Cutin{}), do: {:world, :cutin}
  def route(%Aesir.Net.SoundEffect{}), do: {:world, :sound_effect}
  def route(%Aesir.Net.Emotion{}), do: {:world, :emotion}
  def route(%Aesir.Net.Announcement{}), do: {:world, :announcement}
  def route(%Aesir.Net.NpcDialog{}), do: {:world, :npc_dialog}
  def route(%Aesir.Net.VendingBoardShown{}), do: {:world, :vending_board_shown}
  def route(%Aesir.Net.VendingBoardRemoved{}), do: {:world, :vending_board_removed}
  def route(%Aesir.Net.ItemOnGround{}), do: {:world, :item_on_ground}
  def route(%Aesir.Net.ItemVanished{}), do: {:world, :item_vanished}
  def route(%Aesir.Net.PickupResult{}), do: {:world, :pickup_result}
  def route(%Aesir.Net.SkillUnitSnapshot{}), do: {:world, :skill_unit_snapshot}
  def route(%Aesir.Net.SkillUnitSpawn{}), do: {:world, :skill_unit_spawn}
  def route(%Aesir.Net.SkillUnitUpdate{}), do: {:world, :skill_unit_update}
  def route(%Aesir.Net.SkillUnitDespawn{}), do: {:world, :skill_unit_despawn}
  def route(%Aesir.Net.EstimationResult{}), do: {:world, :estimation_result}
  def route(%Aesir.Net.SkillMenu{}), do: {:world, :skill_menu}
  def route(%Aesir.Net.ProductionResult{}), do: {:world, :production_result}
  def route(%Aesir.Net.SkillTextInputRequest{}), do: {:world, :skill_text_input_request}

  def route(%Aesir.Net.SkillList{}), do: {:bulk, :skill_list}
  def route(%Aesir.Net.InventoryList{}), do: {:bulk, :inventory_list}
  def route(%Aesir.Net.CartInfo{}), do: {:bulk, :cart_info}
  def route(%Aesir.Net.VendingList{}), do: {:bulk, :vending_list}
  def route(%Aesir.Net.StorageOpened{}), do: {:bulk, :storage_opened}
  def route(%Aesir.Net.QuestList{}), do: {:bulk, :quest_list}
  def route(%Aesir.Net.HomunculusPrivateState{}), do: {:bulk, :homunculus_private_state}

  def route(%Aesir.Net.Snapshot{}), do: {:snapshots, :snapshot}

  @doc "Returns the permitted delivery audience for an outbound message."
  @spec delivery_scope(struct()) :: :owner_only | :area
  def delivery_scope(%Aesir.Net.HomunculusResult{}), do: :owner_only
  def delivery_scope(%Aesir.Net.HomunculusPrivateState{}), do: :owner_only
  def delivery_scope(_message), do: :area

  @doc """
  Routes `message` and pushes it to the owning `QuicConnection` `pid` as
  `{:send, channel, {tag, message}}` — the async outbound path every handler
  uses to send an `Aesir.Net.*` struct to its client.
  """
  @spec send_to(pid(), struct()) :: :ok
  def send_to(connection_pid, message) do
    {channel, tag} = route(message)
    send(connection_pid, {:send, channel, {tag, message}})
    :ok
  end
end
