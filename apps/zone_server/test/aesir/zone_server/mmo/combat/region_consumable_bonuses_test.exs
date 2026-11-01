defmodule Aesir.ZoneServer.Mmo.Combat.RegionConsumableBonusesTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ManuAtk
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ManuDef
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ManuMatk
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SplAtk
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SplDef
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SplMatk

  setup :setup_ets_tables

  test "region attack buffs join equipment in each group and do not duplicate onto the left hand" do
    attacker = CombatTestHelper.create_player_combatant()

    attacker = %{
      attacker
      | equip_modifiers: %{
          {:addrace2, :manuk} => 3,
          {:left_addrace2, :manuk} => 5,
          {:addrace2, :splendide} => 4,
          {:left_addrace2, :splendide} => 7,
          {:arrow_addrace2, :manuk} => 100
        }
    }

    defender = %{CombatTestHelper.create_mob_combatant() | race2: [:manuk, :splendide]}

    modifiers =
      Map.merge(ManuAtk.modifiers(%{val1: 10}, %{}), SplAtk.modifiers(%{val1: 20}, %{}))

    opts = %{arrow?: false, ranged?: false, range_rates?: false, attacker_modifiers: modifiers}

    assert EquipmentBonuses.physical_attack_cardfix(attacker, defender, :right_hand, opts) ==
             [0, 0, 0, 18, 31, 0, 0]

    assert EquipmentBonuses.physical_attack_cardfix(attacker, defender, :right_hand, %{
             opts
             | arrow?: true,
               ranged?: true
           }) == [0, 0, 0, 37, 0, 0]

    assert EquipmentBonuses.physical_attack_cardfix(attacker, defender, :left_hand, opts) == [0]

    assert EquipmentBonuses.physical_attack_cardfix(
             attacker,
             %{defender | race2: [:goblin]},
             :right_hand,
             opts
           ) == [0, 0, 0, 0, 0, 0]
  end

  test "region defense buffs add to the same card channel for weapon, magic and misc hits" do
    attacker = %{CombatTestHelper.create_mob_combatant() | race2: [:manuk, :splendide]}
    defender = CombatTestHelper.create_player_combatant()

    defender = %{
      defender
      | equip_modifiers: %{{:subrace2, :manuk} => 5, {:subrace2, :splendide} => 3}
    }

    modifiers =
      Map.merge(ManuDef.modifiers(%{val1: 7}, %{}), SplDef.modifiers(%{val1: 11}, %{}))

    flag = BattleFlags.build(:weapon, :short, true)

    physical =
      EquipmentBonuses.physical_defense_cardfix(defender, attacker, %{
        elements: [:neutral],
        ignore_element?: false,
        status_modifiers: modifiers,
        attack_flag: flag,
        ranged?: false
      })

    misc =
      EquipmentBonuses.misc_defense_cardfix(defender, attacker, %{
        element: :neutral,
        ignore_element?: false,
        status_modifiers: modifiers,
        attack_flag: BattleFlags.build(:misc, :short, true)
      })

    assert Enum.at(physical, 3) == 26
    assert Enum.at(misc, 3) == 26

    assert %{race2: 26} =
             EquipmentBonuses.magic_defense_rates(
               defender,
               attacker,
               :neutral,
               modifiers,
               nil,
               BattleFlags.build(:magic, :long, true)
             )
  end

  test "magic input preparation combines both region buffs with cards and honors card suppression" do
    attacker = CombatTestHelper.create_player_combatant()

    attacker = %{
      attacker
      | equip_modifiers: %{{:magic_addrace2, :manuk} => 3, {:magic_addrace2, :splendide} => 7}
    }

    defender = CombatTestHelper.create_mob_combatant()

    defender = %{
      defender
      | race2: [:manuk, :splendide],
        combat_stats: Map.merge(defender.combat_stats, %{mdef: 0, soft_mdef: 0})
    }

    modifiers =
      Map.merge(ManuMatk.modifiers(%{val1: 10}, %{}), SplMatk.modifiers(%{val1: 20}, %{}))

    assert %{attack: %{race2: 40}} =
             DamageInputs.magic_context(attacker, defender, [], modifiers, %{})

    assert %{attack: %{race2: 0}} =
             DamageInputs.magic_context(
               attacker,
               defender,
               [ignore_atk_card: true],
               modifiers,
               %{}
             )

    assert %{attack: %{race2: 0}} =
             DamageInputs.magic_context(
               attacker,
               %{defender | race2: [:goblin]},
               [],
               modifiers,
               %{}
             )
  end
end
