defmodule Aesir.ZoneServer.Packets.ZcNotifyActTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.ZoneServer.Packets.ZcNotifyAct

  doctest ZcNotifyAct

  describe "packet structure" do
    test "has correct packet ID" do
      assert ZcNotifyAct.packet_id() == 0x08C8
    end

    test "has correct packet size" do
      assert ZcNotifyAct.packet_size() == 34
    end

    test "returns attack type constants" do
      types = ZcNotifyAct.attack_types()

      assert types.normal == 0
      assert types.multi_hit == 4
      assert types.critical == 8
      assert types.lucky_dodge == 10
    end
  end

  describe "normal_attack/4" do
    test "creates normal attack packet with required fields" do
      packet = ZcNotifyAct.normal_attack(1001, 2001, 150)

      assert packet.src_id == 1001
      assert packet.target_id == 2001
      assert packet.damage == 150
      # Normal attack
      assert packet.type == 0
      assert packet.div == 1
      assert packet.is_sp_damage == 0
      assert packet.damage2 == 0
    end

    test "uses default values for optional parameters" do
      packet = ZcNotifyAct.normal_attack(1001, 2001, 150)

      assert packet.src_speed == 1000
      assert packet.dmg_speed == 500
    end

    test "accepts custom optional parameters" do
      opts = [
        src_speed: 800,
        dmg_speed: 300,
        damage2: 50,
        div: 2
      ]

      packet = ZcNotifyAct.normal_attack(1001, 2001, 150, opts)

      assert packet.src_speed == 800
      assert packet.dmg_speed == 300
      assert packet.damage2 == 50
      assert packet.div == 2
    end

    test "handles server_tick option" do
      timestamp = ServerTick.now()
      packet = ZcNotifyAct.normal_attack(1001, 2001, 150, server_tick: timestamp)

      assert packet.server_tick == timestamp
    end
  end

  describe "critical_attack/4" do
    test "creates critical attack packet with correct type" do
      packet = ZcNotifyAct.critical_attack(1001, 2001, 300)

      assert packet.src_id == 1001
      assert packet.target_id == 2001
      assert packet.damage == 300
      # Critical attack
      assert packet.type == 8
      assert packet.div == 1
      assert packet.is_sp_damage == 0
      assert packet.damage2 == 0
    end

    test "uses default values for optional parameters" do
      packet = ZcNotifyAct.critical_attack(1001, 2001, 300)

      assert packet.src_speed == 1000
      assert packet.dmg_speed == 500
    end

    test "accepts custom optional parameters" do
      opts = [
        src_speed: 600,
        dmg_speed: 200,
        is_sp_damage: 1
      ]

      packet = ZcNotifyAct.critical_attack(1001, 2001, 300, opts)

      assert packet.src_speed == 600
      assert packet.dmg_speed == 200
      assert packet.is_sp_damage == 1
      # Should remain critical type
      assert packet.type == 8
    end
  end

  describe "miss_attack/3" do
    test "creates miss attack packet with correct values" do
      packet = ZcNotifyAct.miss_attack(1001, 2001)

      assert packet.src_id == 1001
      assert packet.target_id == 2001
      assert packet.damage == 0
      # Lucky dodge
      assert packet.type == 10
      assert packet.div == 1
      assert packet.is_sp_damage == 0
      assert packet.damage2 == 0
    end

    test "uses default speed values" do
      packet = ZcNotifyAct.miss_attack(1001, 2001)

      assert packet.src_speed == 1000
      assert packet.dmg_speed == 500
    end

    test "accepts custom optional parameters" do
      opts = [src_speed: 750, dmg_speed: 400]
      packet = ZcNotifyAct.miss_attack(1001, 2001, opts)

      assert packet.src_speed == 750
      assert packet.dmg_speed == 400
      # Should remain 0 for miss
      assert packet.damage == 0
    end
  end

  describe "from_combat_result/4" do
    test "creates normal attack packet for non-critical combat result" do
      combat_result = %{
        damage: 120,
        is_critical: false,
        critical_rate: 100
      }

      packet = ZcNotifyAct.from_combat_result(1001, 2001, combat_result)

      assert packet.src_id == 1001
      assert packet.target_id == 2001
      assert packet.damage == 120
      # Normal attack
      assert packet.type == 0
    end

    test "creates critical attack packet for critical combat result" do
      combat_result = %{
        damage: 240,
        is_critical: true,
        critical_rate: 500
      }

      packet = ZcNotifyAct.from_combat_result(1001, 2001, combat_result)

      assert packet.src_id == 1001
      assert packet.target_id == 2001
      assert packet.damage == 240
      # Critical attack
      assert packet.type == 8
    end

    test "handles missing combat result fields gracefully" do
      # Empty combat result
      combat_result = %{}

      packet = ZcNotifyAct.from_combat_result(1001, 2001, combat_result)

      assert packet.src_id == 1001
      assert packet.target_id == 2001
      # Default when missing
      assert packet.damage == 0
      # Default to normal when is_critical missing
      assert packet.type == 0
    end

    test "passes through optional parameters" do
      combat_result = %{damage: 100, is_critical: false}
      opts = [src_speed: 900, dmg_speed: 350]

      packet = ZcNotifyAct.from_combat_result(1001, 2001, combat_result, opts)

      assert packet.src_speed == 900
      assert packet.dmg_speed == 350
    end

    test "handles edge case damage values" do
      # Zero damage
      zero_result = %{damage: 0, is_critical: false}
      packet = ZcNotifyAct.from_combat_result(1001, 2001, zero_result)
      assert packet.damage == 0

      # Very high damage
      high_result = %{damage: 99_999, is_critical: true}
      packet = ZcNotifyAct.from_combat_result(1001, 2001, high_result)
      assert packet.damage == 99_999
      assert packet.type == 8
    end
  end

  describe "build/1" do
    test "builds correct binary packet for normal attack" do
      packet = %ZcNotifyAct{
        src_id: 1001,
        target_id: 2001,
        server_tick: 12_345,
        src_speed: 1000,
        dmg_speed: 500,
        damage: 150,
        is_sp_damage: 0,
        div: 1,
        type: 0,
        damage2: 0
      }

      binary = ZcNotifyAct.build(packet)

      # Should start with packet ID
      <<packet_id::16-little, _rest::binary>> = binary
      assert packet_id == 0x08C8

      # Should have correct total length (2 bytes header + 32 bytes data)
      assert byte_size(binary) == 34
    end

    test "builds correct binary packet for critical attack" do
      packet = %ZcNotifyAct{
        src_id: 2001,
        target_id: 3001,
        server_tick: 54_321,
        src_speed: 800,
        dmg_speed: 400,
        damage: 300,
        is_sp_damage: 0,
        div: 1,
        # Critical
        type: 8,
        damage2: 0
      }

      binary = ZcNotifyAct.build(packet)

      # Verify packet structure
      <<
        packet_id::16-little,
        src_id::32-little,
        target_id::32-little,
        server_tick::32-little,
        src_speed::32-little,
        dmg_speed::32-little,
        damage::32-little,
        is_sp_damage::8,
        div::16-little,
        type::8,
        damage2::32-little
      >> = binary

      assert packet_id == 0x08C8
      assert src_id == 2001
      assert target_id == 3001
      assert server_tick == 54_321
      assert src_speed == 800
      assert dmg_speed == 400
      assert damage == 300
      assert is_sp_damage == 0
      assert div == 1
      assert type == 8
      assert damage2 == 0
    end

    test "handles nil server_tick by generating current timestamp" do
      packet = %ZcNotifyAct{
        src_id: 1001,
        target_id: 2001,
        server_tick: nil,
        src_speed: 1000,
        dmg_speed: 500,
        damage: 150,
        is_sp_damage: 0,
        div: 1,
        type: 0,
        damage2: 0
      }

      binary = ZcNotifyAct.build(packet)

      # Extract server_tick from binary
      <<_packet_id::16-little, _src_id::32-little, _target_id::32-little, server_tick::32-little,
        _rest::binary>> = binary

      # Should be a reasonable timestamp (not nil/0)
      assert server_tick > 0

      # Should be close to current time
      current_tick = ServerTick.now()
      assert abs(server_tick - current_tick) < 1000
    end

    test "handles multi-hit attacks correctly" do
      packet = %ZcNotifyAct{
        src_id: 1001,
        target_id: 2001,
        server_tick: 12_345,
        src_speed: 1000,
        dmg_speed: 500,
        damage: 75,
        is_sp_damage: 0,
        # Multi-hit
        div: 2,
        # Multi-hit type
        type: 4,
        # Second hit damage
        damage2: 75
      }

      binary = ZcNotifyAct.build(packet)

      # Verify multi-hit fields
      <<_::binary-size(27), div::16-little, type::8, damage2::32-little>> = binary

      assert div == 2
      assert type == 4
      assert damage2 == 75
    end

    test "handles SP damage correctly" do
      packet = %ZcNotifyAct{
        src_id: 1001,
        target_id: 2001,
        server_tick: 12_345,
        src_speed: 1000,
        dmg_speed: 500,
        damage: 50,
        # SP damage
        is_sp_damage: 1,
        div: 1,
        type: 0,
        damage2: 0
      }

      binary = ZcNotifyAct.build(packet)

      # Verify SP damage flag
      <<_::binary-size(26), is_sp_damage::8, _rest::binary>> = binary
      assert is_sp_damage == 1
    end
  end

  describe "integration tests" do
    test "complete workflow: combat result to binary packet" do
      # Simulate critical hit combat result
      combat_result = %{
        damage: 456,
        is_critical: true,
        critical_rate: 300
      }

      # Create packet from combat result
      packet =
        ZcNotifyAct.from_combat_result(5001, 6001, combat_result,
          src_speed: 750,
          dmg_speed: 300
        )

      # Build binary
      binary = ZcNotifyAct.build(packet)

      # Verify the complete packet
      <<
        packet_id::16-little,
        src_id::32-little,
        target_id::32-little,
        _server_tick::32-little,
        src_speed::32-little,
        dmg_speed::32-little,
        damage::32-little,
        is_sp_damage::8,
        div::16-little,
        type::8,
        damage2::32-little
      >> = binary

      assert packet_id == 0x08C8
      assert src_id == 5001
      assert target_id == 6001
      assert src_speed == 750
      assert dmg_speed == 300
      assert damage == 456
      assert is_sp_damage == 0
      assert div == 1
      # Critical
      assert type == 8
      assert damage2 == 0
    end

    test "normal attack workflow" do
      combat_result = %{damage: 123, is_critical: false}

      packet = ZcNotifyAct.from_combat_result(7001, 8001, combat_result)
      binary = ZcNotifyAct.build(packet)

      # Should be valid packet
      assert is_binary(binary)
      assert byte_size(binary) == 34

      # Should have normal attack type
      <<_::binary-size(30), type::8, _::binary>> = binary
      assert type == 0
    end

    test "miss attack workflow" do
      packet = ZcNotifyAct.miss_attack(9001, 9002, src_speed: 1200)
      binary = ZcNotifyAct.build(packet)

      # Extract key fields
      <<_packet_id::16-little, src_id::32-little, target_id::32-little, _server_tick::32-little,
        src_speed::32-little, _dmg_speed::32-little, damage::32-little, _is_sp_damage::8,
        _div::16-little, type::8, _damage2::32-little>> = binary

      assert src_id == 9001
      assert target_id == 9002
      assert src_speed == 1200
      assert damage == 0
      # Lucky dodge
      assert type == 10
    end
  end
end
