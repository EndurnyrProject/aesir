defmodule Aesir.ZoneServer.Packets.ZcInventoryStartTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.ZcInventoryStart

  describe "ZcInventoryStart packet" do
    test "has correct packet id" do
      assert ZcInventoryStart.packet_id() == 0x0B08
    end

    test "is a variable-size packet" do
      assert ZcInventoryStart.packet_size() == :variable
    end

    test "builds a binary carrying inv type and a NUL-terminated name" do
      binary = ZcInventoryStart.build(%ZcInventoryStart{inv_type: 0, name: "Inventory"})

      <<packet_id::16-little, length::16-little, inv_type::8, name::binary>> = binary

      assert packet_id == 0x0B08
      assert inv_type == 0
      assert byte_size(binary) == length
      assert name == <<"Inventory", 0>>
    end

    test "defaults to the normal inventory type and an empty name" do
      binary = ZcInventoryStart.build(%ZcInventoryStart{})

      <<0x0B08::16-little, length::16-little, 0::8, name::binary>> = binary

      assert byte_size(binary) == length
      assert name == <<0>>
    end
  end
end
