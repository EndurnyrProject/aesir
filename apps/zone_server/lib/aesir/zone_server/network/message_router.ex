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
  def route(%Aesir.Net.EquipResult{}), do: {:gameplay, :equip_result}
  def route(%Aesir.Net.UnequipResult{}), do: {:gameplay, :unequip_result}
  def route(%Aesir.Net.ItemAdded{}), do: {:gameplay, :item_added}
  def route(%Aesir.Net.ItemRemoved{}), do: {:gameplay, :item_removed}
  def route(%Aesir.Net.StatUpResult{}), do: {:gameplay, :stat_up_result}
  def route(%Aesir.Net.LearnSkillResult{}), do: {:gameplay, :learn_skill_result}
  def route(%Aesir.Net.ItemUseResult{}), do: {:gameplay, :item_use_result}
  def route(%Aesir.Net.ParamChange{}), do: {:gameplay, :param_change}
  def route(%Aesir.Net.Resurrect{}), do: {:gameplay, :resurrect}

  def route(%Aesir.Net.UnitSpawn{}), do: {:world, :unit_spawn}
  def route(%Aesir.Net.UnitDespawn{}), do: {:world, :unit_despawn}
  def route(%Aesir.Net.GroundSkill{}), do: {:world, :ground_skill}
  def route(%Aesir.Net.SpriteChange{}), do: {:world, :sprite_change}
  def route(%Aesir.Net.UnitHp{}), do: {:world, :unit_hp}
  def route(%Aesir.Net.NameResponse{}), do: {:world, :name_response}
  def route(%Aesir.Net.ChatMessage{}), do: {:world, :chat_message}
  def route(%Aesir.Net.StatusChange{}), do: {:world, :status_change}
  def route(%Aesir.Net.UnitStateChange{}), do: {:world, :unit_state_change}
  def route(%Aesir.Net.SpecialEffect{}), do: {:world, :special_effect}

  def route(%Aesir.Net.SkillList{}), do: {:bulk, :skill_list}
  def route(%Aesir.Net.InventoryList{}), do: {:bulk, :inventory_list}

  def route(%Aesir.Net.Snapshot{}), do: {:snapshots, :snapshot}

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
