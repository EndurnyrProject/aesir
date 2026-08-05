defmodule Aesir.ZoneServer.Mmo.Combat.PacketFactoryTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory

  describe "build_weapon_swing_packet/3" do
    test "publishes one settled primary component" do
      attacker = CombatTestHelper.create_player_combatant(attack_delay_ms: 500)
      defender = CombatTestHelper.create_mob_combatant()

      assert %DamageDealt{damage: 100, damage2: 0, div: 1, type: 0} =
               PacketFactory.build_weapon_swing_packet(attacker, defender, swing(100))
    end

    test "publishes dual-dagger components without turning them into divisions" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert %DamageDealt{damage: 100, damage2: 40, div: 1, type: 0} =
               PacketFactory.build_weapon_swing_packet(
                 attacker,
                 defender,
                 swing(100, secondary: 40)
               )
    end

    test "publishes the derived Katar secondary in damage2" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert %DamageDealt{damage: 100, damage2: 21, div: 1, type: 0} =
               PacketFactory.build_weapon_swing_packet(
                 attacker,
                 defender,
                 swing(100, secondary: 21)
               )
    end

    test "uses div only for Double Attack presentation" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert %DamageDealt{damage: 100, damage2: 0, div: 2, type: 4} =
               PacketFactory.build_weapon_swing_packet(
                 attacker,
                 defender,
                 swing(100, divisions: 2)
               )
    end

    test "retains the critical attack type for a critical swing" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert %DamageDealt{damage: 200, damage2: 20, div: 1, type: 8} =
               PacketFactory.build_weapon_swing_packet(
                 attacker,
                 defender,
                 swing(200, secondary: 20, outcome: :critical)
               )
    end
  end

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
        PacketFactory.build_attack_packet(
          attacker,
          defender,
          %{damage: 50, is_critical: false},
          2
        )

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

  defp swing(primary_damage, opts \\ []) do
    secondary_damage = Keyword.get(opts, :secondary)
    outcome = Keyword.get(opts, :outcome, :hit)

    %HandedAttack{
      primary: %{damage: primary_damage, is_critical: outcome == :critical},
      secondary:
        if(secondary_damage,
          do: %{damage: secondary_damage, is_critical: outcome == :critical}
        ),
      raw_total: primary_damage + secondary_damage(secondary_damage),
      display_divisions: Keyword.get(opts, :divisions, 1),
      outcome: outcome,
      primary_element: :neutral
    }
  end

  defp secondary_damage(nil), do: 0
  defp secondary_damage(damage), do: damage

  describe "attack speed is no longer inverted" do
    test "a higher-ASPD attacker emits a smaller src_speed than a lower-ASPD one" do
      fast =
        CombatTestHelper.create_player_combatant(
          attack_delay_ms: AttackSpeed.calculate_delay(193)
        )

      slow =
        CombatTestHelper.create_player_combatant(
          attack_delay_ms: AttackSpeed.calculate_delay(150)
        )

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
