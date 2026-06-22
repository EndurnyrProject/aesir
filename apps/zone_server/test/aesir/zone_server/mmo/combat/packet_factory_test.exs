defmodule Aesir.ZoneServer.Mmo.Combat.PacketFactoryTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory

  describe "src_speed / src_delay carry the attacker's attack cadence" do
    setup do
      attacker = CombatTestHelper.create_player_combatant(attack_delay_ms: 500)
      defender = CombatTestHelper.create_mob_combatant()
      {:ok, attacker: attacker, defender: defender}
    end

    test "single-hit attack uses attack_delay_ms as src_speed", %{
      attacker: attacker,
      defender: defender
    } do
      packet =
        PacketFactory.build_attack_packet(attacker, defender, %{damage: 100, is_critical: false})

      assert %DamageDealt{src_speed: 500} = packet
    end

    test "critical attack uses attack_delay_ms as src_speed", %{
      attacker: attacker,
      defender: defender
    } do
      packet =
        PacketFactory.build_attack_packet(attacker, defender, %{damage: 200, is_critical: true})

      assert %DamageDealt{src_speed: 500} = packet
    end

    test "multi-hit attack uses attack_delay_ms as src_speed", %{
      attacker: attacker,
      defender: defender
    } do
      packet =
        PacketFactory.build_attack_packet(attacker, defender, %{damage: 50, is_critical: false}, 2)

      assert %DamageDealt{src_speed: 500, div: 2} = packet
    end

    test "skill damage uses attack_delay_ms as src_delay", %{
      attacker: attacker,
      defender: defender
    } do
      packet =
        PacketFactory.build_skill_damage_packet(attacker, defender, 5, 10, %{
          damage: 300,
          is_critical: false
        })

      assert %SkillDamage{src_delay: 500} = packet
    end

    test "miss uses attack_delay_ms as src_speed", %{attacker: attacker, defender: defender} do
      assert %DamageDealt{src_speed: 500} = PacketFactory.build_miss_packet(attacker, defender)
    end

    test "perfect dodge uses attack_delay_ms as src_speed", %{
      attacker: attacker,
      defender: defender
    } do
      assert %DamageDealt{src_speed: 500} =
               PacketFactory.build_perfect_dodge_packet(attacker, defender)
    end
  end

  describe "attack speed is no longer inverted" do
    test "a higher-ASPD attacker emits a smaller src_speed than a lower-ASPD one" do
      fast = CombatTestHelper.create_player_combatant(attack_delay_ms: AttackSpeed.calculate_delay(193))
      slow = CombatTestHelper.create_player_combatant(attack_delay_ms: AttackSpeed.calculate_delay(150))
      defender = CombatTestHelper.create_mob_combatant()

      result = %{damage: 100, is_critical: false}

      %DamageDealt{src_speed: fast_speed} =
        PacketFactory.build_attack_packet(fast, defender, result)

      %DamageDealt{src_speed: slow_speed} =
        PacketFactory.build_attack_packet(slow, defender, result)

      assert fast_speed < slow_speed
    end
  end
end
