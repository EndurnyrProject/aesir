defmodule Aesir.ZoneServer.Network.MessageRouterTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.Envelope
  alias Aesir.ZoneServer.Network.MessageRouter

  @routes [
    {%Aesir.Net.HelloAck{}, {:control, :hello_ack}},
    {%Aesir.Net.EnterAck{}, {:control, :enter_ack}},
    {%Aesir.Net.TimeSyncAck{}, {:control, :time_sync_ack}},
    {%Aesir.Net.SelfMove{}, {:gameplay, :self_move}},
    {%Aesir.Net.MoveStop{}, {:gameplay, :move_stop}},
    {%Aesir.Net.DamageDealt{}, {:gameplay, :damage_dealt}},
    {%Aesir.Net.Knockback{}, {:gameplay, :knockback}},
    {%Aesir.Net.SkillCasting{}, {:gameplay, :skill_casting}},
    {%Aesir.Net.SkillEffect{}, {:gameplay, :skill_effect}},
    {%Aesir.Net.SkillDamage{}, {:gameplay, :skill_damage}},
    {%Aesir.Net.CastCancel{}, {:gameplay, :cast_cancel}},
    {%Aesir.Net.SkillCooldown{}, {:gameplay, :skill_cooldown}},
    {%Aesir.Net.EquipResult{}, {:gameplay, :equip_result}},
    {%Aesir.Net.UnequipResult{}, {:gameplay, :unequip_result}},
    {%Aesir.Net.ItemAdded{}, {:gameplay, :item_added}},
    {%Aesir.Net.ItemRemoved{}, {:gameplay, :item_removed}},
    {%Aesir.Net.StatUpResult{}, {:gameplay, :stat_up_result}},
    {%Aesir.Net.ParamChange{}, {:gameplay, :param_change}},
    {%Aesir.Net.Resurrect{}, {:gameplay, :resurrect}},
    {%Aesir.Net.UnitSpawn{}, {:world, :unit_spawn}},
    {%Aesir.Net.UnitDespawn{}, {:world, :unit_despawn}},
    {%Aesir.Net.GroundSkill{}, {:world, :ground_skill}},
    {%Aesir.Net.SpriteChange{}, {:world, :sprite_change}},
    {%Aesir.Net.UnitHp{}, {:world, :unit_hp}},
    {%Aesir.Net.NameResponse{}, {:world, :name_response}},
    {%Aesir.Net.ChatMessage{}, {:world, :chat_message}},
    {%Aesir.Net.SkillList{}, {:bulk, :skill_list}},
    {%Aesir.Net.InventoryList{}, {:bulk, :inventory_list}},
    {%Aesir.Net.Snapshot{}, {:snapshots, :snapshot}}
  ]

  @legal_channels [:control, :gameplay, :world, :bulk, :snapshots]

  defp envelope_oneof_tags do
    Envelope.schema().fields
    |> Enum.filter(fn {_name, field} -> match?(%Protox.OneOf{parent: :body}, field.kind) end)
    |> Enum.map(fn {name, _field} -> name end)
    |> MapSet.new()
  end

  describe "route/1" do
    for {struct, expected} <- @routes do
      test "routes #{inspect(struct.__struct__)} to #{inspect(expected)}" do
        assert MessageRouter.route(unquote(Macro.escape(struct))) == unquote(expected)
      end
    end

    test "every returned channel is a legal QuinnetCodec channel" do
      for {struct, _} <- @routes do
        {channel, _tag} = MessageRouter.route(struct)
        assert channel in @legal_channels
      end
    end

    test "every returned tag is a real Envelope oneof field" do
      valid_tags = envelope_oneof_tags()

      for {struct, _} <- @routes do
        {_channel, tag} = MessageRouter.route(struct)
        assert MapSet.member?(valid_tags, tag), "#{inspect(tag)} is not an Envelope oneof field"
      end
    end

    test "raises for an unmapped struct" do
      unmapped = struct(Aesir.Net.MoveRequest, %{})
      assert_raise FunctionClauseError, fn -> MessageRouter.route(unmapped) end
    end
  end
end
