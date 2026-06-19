defmodule Aesir.ZoneServer.Packets.ZcSpriteChangeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.ZcSpriteChange

  describe "ZcSpriteChange packet" do
    test "has correct packet id" do
      assert ZcSpriteChange.packet_id() == 0x01D7
    end

    test "has correct packet size" do
      assert ZcSpriteChange.packet_size() == 15
    end

    test "builds a weapon look with u32 weapon and shield values" do
      packet = ZcSpriteChange.weapon(12_345, 1101, 2104)
      binary = ZcSpriteChange.build(packet)

      assert byte_size(binary) == 15

      <<0x01D7::16-little, gid::32-little, type::8, val::32-little, val2::32-little>> = binary

      assert gid == 12_345
      # LOOK_WEAPON carries both weapon (val) and shield (val2)
      assert type == ZcSpriteChange.look_weapon()
      assert val == 1101
      assert val2 == 2104
    end

    test "builds a shield look (sent under the weapon look with shield as val2)" do
      packet = ZcSpriteChange.shield(12_345, 1101, 2104)
      binary = ZcSpriteChange.build(packet)

      <<0x01D7::16-little, gid::32-little, type::8, val::32-little, val2::32-little>> = binary

      assert gid == 12_345
      assert type == ZcSpriteChange.look_weapon()
      assert val == 1101
      assert val2 == 2104
    end

    test "builds a single-value look with val2 zeroed" do
      packet = ZcSpriteChange.new(12_345, ZcSpriteChange.look_head_top(), 5210)
      binary = ZcSpriteChange.build(packet)

      <<0x01D7::16-little, gid::32-little, type::8, val::32-little, val2::32-little>> = binary

      assert gid == 12_345
      assert type == ZcSpriteChange.look_head_top()
      assert val == 5210
      assert val2 == 0
    end

    test "exposes the LOOK_* type constants" do
      assert ZcSpriteChange.look_weapon() == 2
      assert ZcSpriteChange.look_head_bottom() == 3
      assert ZcSpriteChange.look_head_top() == 4
      assert ZcSpriteChange.look_head_mid() == 5
      assert ZcSpriteChange.look_shield() == 8
    end
  end
end
