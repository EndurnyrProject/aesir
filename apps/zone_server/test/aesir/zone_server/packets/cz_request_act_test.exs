defmodule Aesir.ZoneServer.Packets.CzRequestActTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.CzRequestAct

  describe "parse/1" do
    test "parses valid attack packet correctly" do
      target_id = 12_345
      action = 0

      packet_data = <<0x0437::16-little, target_id::32-little, action::8>>

      assert {:ok, packet} = CzRequestAct.parse(packet_data)
      assert packet.target_id == target_id
      assert packet.action == action
    end

    test "parses continuous attack packet correctly" do
      target_id = 67_890
      action = 7

      packet_data = <<0x0437::16-little, target_id::32-little, action::8>>

      assert {:ok, packet} = CzRequestAct.parse(packet_data)
      assert packet.target_id == target_id
      assert packet.action == action
    end

    test "parses sit action correctly" do
      target_id = 0
      action = 2

      packet_data = <<0x0437::16-little, target_id::32-little, action::8>>

      assert {:ok, packet} = CzRequestAct.parse(packet_data)
      assert packet.target_id == target_id
      assert packet.action == action
    end

    test "returns error for invalid packet size" do
      invalid_packet = <<0x0437::16-little, 123::32-little>>
      assert {:error, :invalid_packet} = CzRequestAct.parse(invalid_packet)
    end

    test "returns error for wrong packet ID" do
      wrong_packet = <<0x0000::16-little, 12_345::32-little, 0::8>>
      assert {:error, :invalid_packet} = CzRequestAct.parse(wrong_packet)
    end

    test "returns error for invalid action value" do
      target_id = 12_345
      # Invalid action value
      invalid_action = 1

      packet_data = <<0x0437::16-little, target_id::32-little, invalid_action::8>>
      assert {:error, :invalid_action} = CzRequestAct.parse(packet_data)
    end

    test "returns error for another invalid action value" do
      target_id = 12_345
      # Invalid action value
      invalid_action = 255

      packet_data = <<0x0437::16-little, target_id::32-little, invalid_action::8>>
      assert {:error, :invalid_action} = CzRequestAct.parse(packet_data)
    end
  end

  describe "packet info" do
    test "has correct packet ID" do
      assert CzRequestAct.packet_id() == 0x0437
    end

    test "has correct packet size" do
      assert CzRequestAct.packet_size() == 7
    end
  end
end
