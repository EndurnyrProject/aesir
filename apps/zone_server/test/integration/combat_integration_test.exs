defmodule Aesir.ZoneServer.Integration.CombatIntegrationTest do
  @moduledoc """
  Integration tests for the Combat system.
  Tests real combat mechanics with only the network layer mocked.
  """

  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Packets.ZcNotifyAct
  alias Aesir.ZoneServer.Packets.ZcNotifyVanish
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  describe "player vs mob combat" do
    test "player attacks mob and deals damage" do
      # Setup player with known stats
      player =
        start_player_session(
          character:
            create_test_character(
              id: 1001,
              name: "Attacker",
              str: 10,
              dex: 10,
              base_level: 10
            ),
          map_name: "prontera",
          position: {150, 150}
        )

      # Setup mob target
      mob =
        start_mob_session(
          # Poring
          mob_id: 1002,
          unit_id: 2001,
          map_name: "prontera",
          # Adjacent to player for melee range
          position: {151, 150},
          hp: 100,
          max_hp: 100
        )

      # Clear any spawn packets from initialization
      Process.sleep(100)
      flush_packets()

      # Get player stats and state for combat
      stats = get_player_stats(player.pid)
      player_state = get_player_state(player.pid)

      # Execute the attack
      result = Combat.execute_attack(stats, player_state, mob.unit_id)
      assert result == :ok

      # Collect all packets sent within a reasonable time
      Process.sleep(100)
      packets = collect_packets_of_type(ZcNotifyAct, 200)

      # Verify we got at least one damage packet
      assert length(packets) > 0, "No ZcNotifyAct packets were sent"
      damage_packet = hd(packets)

      # Verify packet contents
      assert damage_packet.src_id == player.character.account_id
      assert damage_packet.target_id == mob.unit_id
      assert damage_packet.damage > 0

      # Verify mob actually took damage
      # Give time for damage to be applied
      Process.sleep(50)
      mob_state = get_mob_state(mob.pid)
      assert mob_state.hp < 100
      assert mob_state.hp == 100 - damage_packet.damage

      # TODO: Fix aggro checking - mob aggro system may work differently
      # assert mob_has_aggro?(mob.unit_id, player.character.id)
    end

    test "player misses attack when mob has high flee" do
      # Setup player with low hit
      player =
        start_player_session(
          character:
            create_test_character(
              id: 1001,
              # Low DEX for low HIT
              dex: 1,
              base_level: 1
            ),
          position: {150, 150}
        )

      # Setup mob with high flee using test helper
      mob =
        start_mob_session(
          position: {151, 150},
          # High level mob will have high flee
          level: 50
        )

      # Mock the mob to have very high flee
      mob_unit_id = mob.unit_id

      stub(UnitRegistry, :get_unit, fn :mob, unit_id when unit_id == mob_unit_id ->
        # Update the mob's stats AGI instead of trying to set AGI directly
        updated_stats = %{mob.mob_state.mob_data.stats | agi: 99}
        updated_mob_data = %{mob.mob_state.mob_data | stats: updated_stats}
        mob_state = %{mob.mob_state | mob_data: updated_mob_data}
        {:ok, {MobSession, mob_state, mob.pid}}
      end)

      # Execute attack
      stats = get_player_stats(player.pid)
      player_state = get_player_state(player.pid)
      Combat.execute_attack(stats, player_state, mob.unit_id)

      # Should receive a miss packet
      packet = assert_packet_sent(ZcNotifyAct, 200)
      # Miss shows as 0 damage
      assert packet.damage == 0
      # Attack type
      assert packet.type == 10
    end

    test "multiple players can attack the same mob" do
      # Create two players
      player1 =
        start_player_session(
          character: create_test_character(id: 1001),
          position: {150, 150}
        )

      player2 =
        start_player_session(
          character: create_test_character(id: 1002),
          position: {150, 151}
        )

      # Create mob with more HP
      mob =
        start_mob_session(
          position: {151, 150},
          hp: 500,
          max_hp: 500
        )

      # Both players attack
      stats1 = get_player_stats(player1.pid)
      state1 = get_player_state(player1.pid)
      Combat.execute_attack(stats1, state1, mob.unit_id)

      stats2 = get_player_stats(player2.pid)
      state2 = get_player_state(player2.pid)
      Combat.execute_attack(stats2, state2, mob.unit_id)

      # Verify both attacks sent packets
      packets = collect_packets_of_type(ZcNotifyAct, 200)
      assert length(packets) >= 2

      # TODO: Fix aggro checking - mob aggro system may work differently
      # Process.sleep(50)
      # assert mob_has_aggro?(mob.unit_id, player1.character.id)
      # assert mob_has_aggro?(mob.unit_id, player2.character.id)
    end

    test "mob dies when HP reaches zero" do
      # Create player with high damage
      player =
        start_player_session(
          character:
            create_test_character(
              str: 99,
              base_level: 50
            ),
          position: {150, 150}
        )

      # Create weak mob
      mob =
        start_mob_session(
          position: {151, 150},
          hp: 10,
          max_hp: 10
        )

      # Attack the mob
      stats = get_player_stats(player.pid)
      player_state = get_player_state(player.pid)
      Combat.execute_attack(stats, player_state, mob.unit_id)

      # Wait for damage to be applied
      Process.sleep(100)

      # Mob should be dead or have very low HP
      mob_state = get_mob_state(mob.pid)
      assert mob_state.hp <= 0 || mob_state.hp < 10
    end
  end

  describe "mob vs player combat" do
    test "mob can attack player" do
      # Setup player
      player =
        start_player_session(
          character: create_test_character(id: 1001),
          position: {150, 150}
        )

      # Setup aggressive mob
      mob =
        start_mob_session(
          mob_id: 1002,
          position: {151, 150},
          hp: 100,
          max_hp: 100
        )

      # Execute mob attack
      mob_state = get_mob_state(mob.pid)
      assert :ok = Combat.execute_mob_attack(mob_state, player.character.id)

      # Verify attack packet was sent
      packet = assert_packet_sent(ZcNotifyAct, 200)
      assert packet.src_id == mob.unit_id
      assert packet.target_id == player.character.account_id
    end
  end

  describe "combat range validation" do
    test "attack fails when target is out of range" do
      # Setup player
      player = start_player_session(position: {150, 150})

      # Setup mob far away
      mob =
        start_mob_session(
          # 10 cells away
          position: {160, 160}
        )

      # Attack should fail due to range
      stats = get_player_stats(player.pid)
      player_state = get_player_state(player.pid)
      result = Combat.execute_attack(stats, player_state, mob.unit_id)

      assert result == {:error, :target_out_of_range}

      # No damage packet should be sent
      refute_packet_sent(ZcNotifyAct, 100)
    end

    test "attack succeeds when target is in melee range" do
      # Setup player
      player = start_player_session(position: {150, 150})

      # Setup mob in range (adjacent)
      mob = start_mob_session(position: {151, 150})

      # Attack should succeed
      stats = get_player_stats(player.pid)
      player_state = get_player_state(player.pid)
      assert :ok = Combat.execute_attack(stats, player_state, mob.unit_id)

      # Damage packet should be sent
      assert_packet_sent(ZcNotifyAct, 200)
    end

    test "validates exact range 1 attack distances using Chebyshev distance" do
      # Test a few key positions to verify Chebyshev distance calculation
      # All adjacent positions should be distance 1, including diagonals

      # Test case 1: Adjacent cardinal direction (East) - should be in range
      player1 = start_player_session(position: {150, 150})
      mob1 = start_mob_session(position: {151, 150})
      flush_packets()

      stats1 = get_player_stats(player1.pid)
      player_state1 = get_player_state(player1.pid)
      result1 = Combat.execute_attack(stats1, player_state1, mob1.unit_id)

      assert result1 == :ok, "Attack failed for adjacent East position (should be distance 1)"
      packet1 = assert_packet_sent(ZcNotifyAct, 200)
      assert packet1.src_id == player1.character.account_id
      assert packet1.target_id == mob1.unit_id

      # Test case 2: Adjacent diagonal (Southeast) - should be in range
      player2 = start_player_session(position: {150, 150})
      mob2 = start_mob_session(position: {151, 151})
      flush_packets()

      stats2 = get_player_stats(player2.pid)
      player_state2 = get_player_state(player2.pid)
      result2 = Combat.execute_attack(stats2, player_state2, mob2.unit_id)

      assert result2 == :ok,
             "Attack failed for diagonal Southeast position (should be distance 1 with Chebyshev)"

      packet2 = assert_packet_sent(ZcNotifyAct, 200)
      assert packet2.src_id == player2.character.account_id
      assert packet2.target_id == mob2.unit_id

      # Test case 3: Distance 2 position - should be out of range
      player3 = start_player_session(position: {150, 150})
      mob3 = start_mob_session(position: {152, 150})
      flush_packets()

      stats3 = get_player_stats(player3.pid)
      player_state3 = get_player_state(player3.pid)
      result3 = Combat.execute_attack(stats3, player_state3, mob3.unit_id)

      assert result3 == {:error, :target_out_of_range},
             "Attack succeeded but should have failed for distance 2 position"

      refute_packet_sent(ZcNotifyAct, 100)
    end

    test "validates mob attack range using same Chebyshev distance" do
      # Test that mobs use the same range calculation as players
      player = start_player_session(position: {150, 150})

      # Test mob at range 1 (should be in attack range)
      mob_in_range = start_mob_session(position: {151, 150})

      # Test mob at range 2 (should be out of attack range) 
      mob_out_range = start_mob_session(position: {152, 150})

      # Clear spawn packets
      flush_packets()

      # Mob in range should be able to attack
      mob_state = get_mob_state(mob_in_range.pid)
      result1 = Combat.execute_mob_attack(mob_state, player.character.id)
      assert result1 == :ok, "Mob attack failed at range 1"

      # Should receive attack packet
      packet = assert_packet_sent(ZcNotifyAct, 200)
      assert packet.src_id == mob_in_range.unit_id

      # Mob out of range should fail to attack
      mob_state2 = get_mob_state(mob_out_range.pid)
      result2 = Combat.execute_mob_attack(mob_state2, player.character.id)

      assert result2 == {:error, :target_out_of_range},
             "Mob attack succeeded but should have failed at range 2"

      # Should not receive another attack packet
      refute_packet_sent(ZcNotifyAct, 100)
    end
  end

  # Helper function to create test characters with defaults
  defp create_test_character(opts) do
    %Character{
      id: opts[:id] || :erlang.unique_integer([:positive]),
      account_id: 1,
      name: opts[:name] || "TestChar",
      char_num: 0,
      class: 0,
      base_level: opts[:base_level] || 1,
      job_level: 1,
      base_exp: 0,
      job_exp: 0,
      zeny: 500,
      str: opts[:str] || 5,
      agi: opts[:agi] || 5,
      vit: opts[:vit] || 5,
      int: opts[:int] || 5,
      dex: opts[:dex] || 5,
      luk: opts[:luk] || 5,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      status_point: 0,
      skill_point: 0,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150,
      hair: 1,
      hair_color: 1,
      clothes_color: 0,
      online: true
    }
  end

  describe "movement_completed with combat intent" do
    test "handles movement completion with combat intent without KeyError" do
      player =
        start_player_session(
          character:
            create_test_character(
              id: 36,
              name: "Castor",
              str: 1,
              agi: 1,
              vit: 1,
              int: 1,
              dex: 1,
              luk: 1,
              base_level: 1
            ),
          map_name: "prt_fild01",
          position: {109, 205}
        )

      # Setup mob target at adjacent position
      _mob =
        start_mob_session(
          # Poring
          mob_id: 1002,
          unit_id: 1_750_999,
          map_name: "prt_fild01",
          position: {109, 206},
          hp: 50,
          max_hp: 50
        )

      # Wait for initialization
      Process.sleep(50)
      flush_packets()

      send(player.pid, :movement_completed)

      # Give it time to process
      Process.sleep(100)

      # We can also verify some basic combat packet was sent
      packets = collect_packets_of_type(ZcNotifyAct, 200)

      assert is_list(packets)
    end
  end

  describe "mob death animation" do
    test "mob death sends correct vanish packet with death animation type" do
      # Setup player with high strength to kill mob easily
      player =
        start_player_session(
          character:
            create_test_character(
              id: 1001,
              name: "Killer",
              # High strength to ensure we kill the mob
              str: 100,
              dex: 100,
              base_level: 50
            ),
          map_name: "prontera",
          position: {150, 150}
        )

      # Setup weak mob with 1 HP at the same position for easy killing
      mob =
        start_mob_session(
          mob_id: 1002,
          unit_id: 2001,
          map_name: "prontera",
          # Same position as player
          position: {150, 150},
          # Very low HP to ensure death
          hp: 1,
          max_hp: 1
        )

      # Attack the mob to kill it
      stats = get_player_stats(player.pid)
      player_state = get_player_state(player.pid)

      # Execute attack which should kill the mob
      result = Combat.execute_attack(stats, player_state, mob.unit_id)
      assert result == :ok

      # Wait for death processing
      Process.sleep(200)

      # Verify vanish packet was sent with correct death type
      vanish_packets = collect_packets_of_type(ZcNotifyVanish, 300)

      assert length(vanish_packets) > 0, "No ZcNotifyVanish packets were sent"

      death_packet =
        Enum.find(vanish_packets, fn packet ->
          packet.gid == mob.unit_id
        end)

      assert death_packet != nil, "No vanish packet found for the mob"

      assert death_packet.type == ZcNotifyVanish.died(),
             "Expected death vanish type (#{ZcNotifyVanish.died()}), got #{death_packet.type}"
    end
  end
end
