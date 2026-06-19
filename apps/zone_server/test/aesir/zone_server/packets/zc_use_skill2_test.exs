defmodule Aesir.ZoneServer.Packets.ZcUseSkill2Test do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.PacketRegistry
  alias Aesir.ZoneServer.Packets.ZcUseSkill2

  describe "registration" do
    test "is registered in the packet registry" do
      assert PacketRegistry.get_module(0x0B1A) == ZcUseSkill2
    end
  end

  describe "packet metadata" do
    test "packet_id/0 is 0x0B1A" do
      assert ZcUseSkill2.packet_id() == 0x0B1A
    end

    test "packet_size/0 is 29" do
      assert ZcUseSkill2.packet_size() == 29
    end
  end

  describe "build/1" do
    test "encodes the full little-endian byte layout" do
      packet = %ZcUseSkill2{
        src_id: 2_000_001,
        dst_id: 2_000_002,
        x: 150,
        y: 99,
        skill_id: 83,
        property: 1,
        cast_time: 5_000,
        disposable: 0,
        attack_motion_time: 1_500
      }

      binary = ZcUseSkill2.build(packet)

      assert byte_size(binary) == 29

      assert binary ==
               <<0x0B1A::16-little, 2_000_001::32-little, 2_000_002::32-little, 150::16-little,
                 99::16-little, 83::16-little, 1::32-little, 5_000::32-little, 0::8,
                 1_500::32-little>>
    end

    test "disposable and attack_motion_time default to 0" do
      binary =
        ZcUseSkill2.build(%ZcUseSkill2{
          src_id: 1,
          dst_id: 2,
          x: 0,
          y: 0,
          skill_id: 0,
          property: 0,
          cast_time: 0
        })

      assert byte_size(binary) == 29
      assert <<_::binary-size(24), 0::8, 0::32-little>> = binary
    end
  end
end
