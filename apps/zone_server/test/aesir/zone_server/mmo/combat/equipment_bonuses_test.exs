defmodule Aesir.ZoneServer.Mmo.Combat.EquipmentBonusesTest do
  @moduledoc """
  Tests for the pure equipment-bonus read surface used by combat.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.BattleFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses

  describe "attack_rates/4" do
    test "sums specific-param and :all within each family" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:addrace, :brute} => 20,
          {:addrace, :all} => 5,
          {:addclass, :normal} => 3,
          {:addclass, :all} => 2,
          {:addele, :earth} => 10,
          {:addele, :all} => 1,
          {:addsize, :medium} => 15,
          {:addsize, :all} => 5,
          {:skill_atk, 100} => 30
        })

      defender =
        CombatTestHelper.create_mob_combatant(race: :brute, size: :medium)
        |> Map.put(:element, {:earth, 1})

      assert EquipmentBonuses.attack_rates(attacker, defender, 100, :earth) == %{
               race_class: 25 + 5,
               element: 11,
               size: 20,
               skill: 30
             }
    end

    test "secondary monster groups add physical and magic attack bonuses" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:addrace2, :goblin} => 20, {:magic_addrace2, :goblin} => 30})

      defender = %{CombatTestHelper.create_mob_combatant() | race2: [:goblin]}

      assert EquipmentBonuses.attack_rates(attacker, defender, nil, :neutral) == %{
               race_class: 20,
               element: 0,
               size: 0,
               skill: 0
             }

      assert EquipmentBonuses.magic_attack_rates(attacker, defender, nil, :neutral) == %{
               race: 30,
               class: 0,
               element_target: 0,
               size: 0,
               atk_ele: 0,
               skill: 0
             }
    end

    test "secondary monster group all bonus is counted once" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:addrace2, :goblin} => 10,
          {:addrace2, :orc} => 15,
          {:addrace2, :all} => 5
        })

      defender = %{CombatTestHelper.create_mob_combatant() | race2: [:goblin, :orc]}

      assert EquipmentBonuses.attack_rates(attacker, defender, nil, :neutral) == %{
               race_class: 30,
               element: 0,
               size: 0,
               skill: 0
             }
    end

    test "empty secondary monster groups do not match exact bonuses" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:addrace2, :goblin} => 20, {:magic_addrace2, :goblin} => 30})

      defender = %{CombatTestHelper.create_mob_combatant() | race2: []}

      assert EquipmentBonuses.attack_rates(attacker, defender, nil, :neutral) == %{
               race_class: 0,
               element: 0,
               size: 0,
               skill: 0
             }

      assert EquipmentBonuses.magic_attack_rates(attacker, defender, nil, :neutral) == %{
               race: 0,
               class: 0,
               element_target: 0,
               size: 0,
               atk_ele: 0,
               skill: 0
             }
    end

    test "race and class share one family group" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:addrace, :brute} => 20, {:addclass, :boss} => 40})

      defender =
        CombatTestHelper.create_boss_mob(race: :brute)
        |> Map.put(:class, :boss)

      assert %{race_class: 60} = EquipmentBonuses.attack_rates(attacker, defender, nil, :neutral)
    end

    test "boss-class defender picks up {:addclass, :boss}" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:addclass, :boss} => 25})

      defender =
        CombatTestHelper.create_boss_mob()
        |> Map.put(:class, :boss)

      assert %{race_class: 25} = EquipmentBonuses.attack_rates(attacker, defender, nil, :neutral)
    end

    test "add_damage_class adds physical damage against the target monster id" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:add_damage_class, 1002} => 25})

      defender = CombatTestHelper.create_mob_combatant(monster_id: 1002)

      assert %{race_class: 25} = EquipmentBonuses.attack_rates(attacker, defender, nil, :neutral)
    end

    test "add_damage_class does not apply to a different monster id or to players" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:add_damage_class, 1002} => 25})

      other_mob = CombatTestHelper.create_mob_combatant(monster_id: 1099)
      player = CombatTestHelper.create_player_combatant()

      assert %{race_class: 0} = EquipmentBonuses.attack_rates(attacker, other_mob, nil, :neutral)
      assert %{race_class: 0} = EquipmentBonuses.attack_rates(attacker, player, nil, :neutral)
    end

    test "skill_id nil returns 0 for the skill family" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:skill_atk, 100} => 30})

      defender = CombatTestHelper.create_mob_combatant()

      assert %{skill: 0} = EquipmentBonuses.attack_rates(attacker, defender, nil, :neutral)
    end

    test "empty equip_modifiers returns all zeros" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert EquipmentBonuses.attack_rates(attacker, defender, nil, :neutral) == %{
               race_class: 0,
               element: 0,
               size: 0,
               skill: 0
             }
    end
  end

  describe "damage_taken_rates/3" do
    test "sums subrace/subclass/subele/subsize with :all" do
      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{
          {:subrace, :brute} => 10,
          {:subrace, :all} => 5,
          {:subclass, :normal} => 3,
          {:subclass, :all} => 2,
          {:subele, :fire} => 8,
          {:subele, :all} => 1,
          {:subsize, :medium} => 6,
          {:subsize, :all} => 4
        })

      attacker = CombatTestHelper.create_player_combatant(race: :brute, size: :medium)

      assert EquipmentBonuses.damage_taken_rates(defender, attacker, :fire) == %{
               race_class: 15 + 5,
               element: 9,
               size: 10,
               skill: 0
             }
    end

    test "a trigger-flagged resist applies only to attacks its flag matches" do
      magic_only = BattleFlags.fill_battle(BattleFlag.id(:magic))
      weapon_only = BattleFlags.fill_battle(BattleFlag.id(:weapon))

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{
          {:subele, :fire} => 5,
          {:subele, {:fire, magic_only}} => 30,
          {:subele, {:fire, weapon_only}} => 7
        })

      attacker = CombatTestHelper.create_player_combatant()

      magic_hit = BattleFlags.build(:magic, :long, true)
      melee_hit = BattleFlags.build(:weapon, :short, false)

      # The unflagged entry applies to everything; each flagged entry only to
      # the attack kind it names.
      assert %{element: 35} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :fire, %{}, nil, magic_hit)

      assert %{element: 12} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :fire, %{}, nil, melee_hit)
    end

    test "a flagged :all entry covers every param of its family" do
      weapon_only = BattleFlags.fill_battle(BattleFlag.id(:weapon))

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{{:subele, {:all, weapon_only}} => 15})

      attacker = CombatTestHelper.create_player_combatant()
      melee_hit = BattleFlags.build(:weapon, :short, false)

      assert %{element: 15} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :fire, %{}, nil, melee_hit)

      assert %{element: 15} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :holy, %{}, nil, melee_hit)
    end

    test "flagged resists of the race, class and size families gate the same way" do
      normal_only = BattleFlags.fill_battle(BattleFlag.id(:normal))

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{
          {:subrace, {:brute, normal_only}} => 10,
          {:subclass, {:normal, normal_only}} => 4,
          {:subsize, {:medium, normal_only}} => 6
        })

      attacker = CombatTestHelper.create_player_combatant(race: :brute, size: :medium)

      swing = BattleFlags.build(:weapon, :short, false)
      skill = BattleFlags.build(:weapon, :short, true)

      assert %{race_class: 14, size: 6} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral, %{}, nil, swing)

      assert %{race_class: 0, size: 0} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral, %{}, nil, skill)
    end

    test "flagged entries stay inert for a caller that passes no classification" do
      weapon_only = BattleFlags.fill_battle(BattleFlag.id(:weapon))

      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{{:subele, {:fire, weapon_only}} => 30})

      attacker = CombatTestHelper.create_player_combatant()

      assert %{element: 0} = EquipmentBonuses.damage_taken_rates(defender, attacker, :fire)
    end

    test "secondary monster groups sum matching damage-taken bonuses" do
      defender =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:subrace2, :goblin} => 10, {:subrace2, :orc} => 15})

      attacker = %{CombatTestHelper.create_mob_combatant() | race2: [:goblin, :orc]}

      assert EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral) == %{
               race_class: 25,
               element: 0,
               size: 0,
               skill: 0
             }
    end

    test "sub_def_ele resists by the attacker's defensive element, not the attack element" do
      defender =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:sub_def_ele, :earth} => 12, {:sub_def_ele, :all} => 3})

      # Attacker's own element is :earth while the incoming hit is :fire, so a
      # match proves the key is read off the attacker's defensive element.
      attacker = CombatTestHelper.create_mob_combatant(element: :earth)

      assert %{element: 15} = EquipmentBonuses.damage_taken_rates(defender, attacker, :fire)
    end

    test "empty equip_modifiers returns all zeros" do
      defender = CombatTestHelper.create_mob_combatant()
      attacker = CombatTestHelper.create_player_combatant()

      assert EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral) == %{
               race_class: 0,
               element: 0,
               size: 0,
               skill: 0
             }
    end

    test "Skin Temper adds fire and neutral resistance only" do
      defender = %{CombatTestHelper.create_player_combatant() | skin_temper_level: 5}
      attacker = CombatTestHelper.create_mob_combatant()

      assert %{element: 25} = EquipmentBonuses.damage_taken_rates(defender, attacker, :fire)
      assert %{element: 5} = EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral)

      for element <- [:holy, :water, :earth, :wind, :poison, :shadow, :ghost, :undead] do
        assert %{element: 0} = EquipmentBonuses.damage_taken_rates(defender, attacker, element)
      end
    end

    test "sums status subele_holy/subrace_demon into equipment element/race families" do
      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{{:subele, :holy} => 10, {:subrace, :demon} => 4})

      attacker = CombatTestHelper.create_player_combatant(race: :demon)
      status = %{subele_holy: 25, subrace_demon: 6}

      assert EquipmentBonuses.damage_taken_rates(defender, attacker, :holy, status) == %{
               race_class: 4 + 6,
               element: 10 + 25,
               size: 0,
               skill: 0
             }
    end

    test "status resist keys are inert against a non-matching element and race" do
      defender = CombatTestHelper.create_mob_combatant()
      attacker = CombatTestHelper.create_player_combatant(race: :human)
      status = %{subele_holy: 25, subrace_demon: 6}

      assert EquipmentBonuses.damage_taken_rates(defender, attacker, :fire, status) == %{
               race_class: 0,
               element: 0,
               size: 0,
               skill: 0
             }
    end

    test "sub_skill reduces only the matching incoming skill id, exactly (no :all)" do
      defender =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:sub_skill, 18} => 30, {:sub_skill, :all} => 99})

      attacker = CombatTestHelper.create_mob_combatant()

      assert %{skill: 30} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral, %{}, 18)

      assert %{skill: 0} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral, %{}, 42)

      assert %{skill: 0} =
               EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral, %{}, nil)
    end
  end

  describe "ranged_damage_taken_rate/3" do
    test "sums defender equipment and status for a ranged hit" do
      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{ranged_damage_taken_rate: -5})

      status = %{ranged_damage_taken_rate: -20}

      assert EquipmentBonuses.ranged_damage_taken_rate(defender, status, true) == -25
    end

    test "returns 0 for a melee hit even with the modifier present" do
      defender = CombatTestHelper.create_mob_combatant()
      status = %{ranged_damage_taken_rate: -20}

      assert EquipmentBonuses.ranged_damage_taken_rate(defender, status, false) == 0
    end
  end

  describe "long_range_defense_rate/3" do
    test "sums defender equipment and status for a ranged hit" do
      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{long_atk_def: 20})

      assert EquipmentBonuses.long_range_defense_rate(defender, %{long_atk_def: 10}, true) == 30
    end

    test "returns 0 for a melee hit even with the modifier present" do
      defender =
        CombatTestHelper.create_mob_combatant()
        |> with_equip_modifiers(%{long_atk_def: 30})

      assert EquipmentBonuses.long_range_defense_rate(defender, %{long_atk_def: 10}, false) == 0
    end
  end

  describe "magic_attack_rates/4" do
    test "sums magic_add* families plus magic_atk_ele and skill" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:magic_addrace, :brute} => 12,
          {:magic_addrace, :all} => 3,
          {:magic_addclass, :normal} => 8,
          {:magic_addclass, :all} => 2,
          {:magic_addele, :earth} => 7,
          {:magic_addele, :all} => 1,
          {:magic_addsize, :medium} => 9,
          {:magic_addsize, :all} => 2,
          {:magic_atk_ele, :earth} => 20,
          {:skill_atk, 200} => 15
        })

      defender =
        CombatTestHelper.create_mob_combatant(race: :brute, size: :medium)
        |> Map.put(:element, {:earth, 1})

      assert EquipmentBonuses.magic_attack_rates(attacker, defender, 200, :earth) == %{
               race: 15,
               class: 10,
               element_target: 8,
               size: 11,
               atk_ele: 20,
               skill: 15
             }
    end

    test "sums class-specific and all magic damage bonuses" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:magic_addclass, :boss} => 12, {:magic_addclass, :all} => 3})

      defender = CombatTestHelper.create_mob_combatant(class: :boss)

      assert %{class: 15} = EquipmentBonuses.magic_attack_rates(attacker, defender, nil, :neutral)
    end

    test "skill_id nil returns 0 for the skill family" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert %{skill: 0} = EquipmentBonuses.magic_attack_rates(attacker, defender, nil, :neutral)
    end

    test "empty equip_modifiers returns all zeros" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert EquipmentBonuses.magic_attack_rates(attacker, defender, nil, :neutral) == %{
               race: 0,
               class: 0,
               element_target: 0,
               size: 0,
               atk_ele: 0,
               skill: 0
             }
    end
  end

  describe "ignore_def_rate/2" do
    test "sums specific race and :all" do
      defender = CombatTestHelper.create_mob_combatant(race: :brute, class: :normal)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_def_race, :brute} => 30,
          {:ignore_def_race, :all} => 10
        })

      assert EquipmentBonuses.ignore_def_rate(attacker, defender) == 40
    end

    test "adds the by-class contribution against the defender's class" do
      defender = CombatTestHelper.create_mob_combatant(race: :brute, class: :boss)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_def_race, :brute} => 20,
          {:ignore_def_class, :boss} => 15,
          {:ignore_def_class, :all} => 5
        })

      assert EquipmentBonuses.ignore_def_rate(attacker, defender) == 40
    end

    test "caps the combined race and class rate at 100" do
      defender = CombatTestHelper.create_mob_combatant(race: :brute, class: :boss)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_def_race, :brute} => 80,
          {:ignore_def_class, :boss} => 80
        })

      assert EquipmentBonuses.ignore_def_rate(attacker, defender) == 100
    end

    test "empty equip_modifiers returns 0" do
      defender = CombatTestHelper.create_mob_combatant(race: :brute, class: :normal)
      attacker = CombatTestHelper.create_player_combatant()

      assert EquipmentBonuses.ignore_def_rate(attacker, defender) == 0
    end
  end

  describe "ignore_mdef_rate/2" do
    test "sums specific race and :all" do
      defender = CombatTestHelper.create_mob_combatant(race: :brute, class: :normal)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_mdef_race, :brute} => 30,
          {:ignore_mdef_race, :all} => 10
        })

      assert EquipmentBonuses.ignore_mdef_rate(attacker, defender) == 40
    end

    test "adds the by-class contribution against the defender's class" do
      defender = CombatTestHelper.create_mob_combatant(race: :brute, class: :boss)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_mdef_race, :brute} => 20,
          {:ignore_mdef_class, :boss} => 15,
          {:ignore_mdef_class, :all} => 5
        })

      assert EquipmentBonuses.ignore_mdef_rate(attacker, defender) == 40
    end

    test "caps the combined race and class rate at 100" do
      defender = CombatTestHelper.create_mob_combatant(race: :brute, class: :boss)

      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_mdef_race, :brute} => 90,
          {:ignore_mdef_class, :boss} => 90
        })

      assert EquipmentBonuses.ignore_mdef_rate(attacker, defender) == 100
    end

    test "empty equip_modifiers returns 0" do
      defender = CombatTestHelper.create_mob_combatant(race: :brute, class: :normal)
      attacker = CombatTestHelper.create_player_combatant()

      assert EquipmentBonuses.ignore_mdef_rate(attacker, defender) == 0
    end
  end

  describe "long_atk_rate/1" do
    test "reads :long_atk_rate when the attacker wields a ranged weapon" do
      attacker =
        CombatTestHelper.create_player_combatant(weapon_type: :bow)
        |> with_equip_modifiers(%{long_atk_rate: 15})

      assert EquipmentBonuses.long_atk_rate(attacker) == 15
    end

    test "returns 0 for a melee attacker carrying the same bonus" do
      attacker =
        CombatTestHelper.create_player_combatant(weapon_type: :sword)
        |> with_equip_modifiers(%{long_atk_rate: 15})

      assert EquipmentBonuses.long_atk_rate(attacker) == 0
    end

    test "returns 0 for a ranged attacker without the bonus" do
      attacker = CombatTestHelper.create_player_combatant(weapon_type: :bow)

      assert EquipmentBonuses.long_atk_rate(attacker) == 0
    end

    test "returns 0 for mobs, which carry no equipment" do
      assert EquipmentBonuses.long_atk_rate(CombatTestHelper.create_mob_combatant()) == 0
    end
  end

  describe "short_atk_rate/1" do
    test "reads :short_atk_rate when the attacker wields a melee weapon" do
      attacker =
        CombatTestHelper.create_player_combatant(weapon_type: :sword)
        |> with_equip_modifiers(%{short_atk_rate: 15})

      assert EquipmentBonuses.short_atk_rate(attacker) == 15
    end

    test "returns 0 for a ranged attacker carrying the same bonus" do
      attacker =
        CombatTestHelper.create_player_combatant(weapon_type: :bow)
        |> with_equip_modifiers(%{short_atk_rate: 15})

      assert EquipmentBonuses.short_atk_rate(attacker) == 0
    end

    test "returns 0 for a melee attacker without the bonus" do
      attacker = CombatTestHelper.create_player_combatant(weapon_type: :sword)

      assert EquipmentBonuses.short_atk_rate(attacker) == 0
    end

    test "returns 0 for mobs, which carry no equipment" do
      assert EquipmentBonuses.short_atk_rate(CombatTestHelper.create_mob_combatant()) == 0
    end

    test "is mutually exclusive with long_atk_rate on the same attacker" do
      bow =
        CombatTestHelper.create_player_combatant(weapon_type: :bow)
        |> with_equip_modifiers(%{short_atk_rate: 15, long_atk_rate: 20})

      sword =
        CombatTestHelper.create_player_combatant(weapon_type: :sword)
        |> with_equip_modifiers(%{short_atk_rate: 15, long_atk_rate: 20})

      assert {EquipmentBonuses.short_atk_rate(bow), EquipmentBonuses.long_atk_rate(bow)} ==
               {0, 20}

      assert {EquipmentBonuses.short_atk_rate(sword), EquipmentBonuses.long_atk_rate(sword)} ==
               {15, 0}
    end
  end

  describe "perfect_hit_rate/1" do
    test "reads :perfect_hit regardless of weapon range" do
      for weapon_type <- [:sword, :bow] do
        attacker =
          CombatTestHelper.create_player_combatant(weapon_type: weapon_type)
          |> with_equip_modifiers(%{perfect_hit: 30})

        assert EquipmentBonuses.perfect_hit_rate(attacker) == 30
      end
    end

    test "returns 0 without the bonus and for mobs" do
      assert EquipmentBonuses.perfect_hit_rate(CombatTestHelper.create_player_combatant()) == 0
      assert EquipmentBonuses.perfect_hit_rate(CombatTestHelper.create_mob_combatant()) == 0
    end
  end

  describe "hp_drain_rate/1 and hp_drain_percent/1" do
    test "read both halves of the drain pair independently" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{hp_drain_rate: 50, hp_drain_percent: 5})

      assert EquipmentBonuses.hp_drain_rate(attacker) == 50
      assert EquipmentBonuses.hp_drain_percent(attacker) == 5
    end

    test "return 0 without the bonus and for mobs" do
      player = CombatTestHelper.create_player_combatant()
      mob = CombatTestHelper.create_mob_combatant()

      assert EquipmentBonuses.hp_drain_rate(player) == 0
      assert EquipmentBonuses.hp_drain_percent(player) == 0
      assert EquipmentBonuses.hp_drain_rate(mob) == 0
      assert EquipmentBonuses.hp_drain_percent(mob) == 0
    end
  end

  describe "splash_range/1" do
    test "reads :splash_range regardless of weapon range" do
      for weapon_type <- [:sword, :bow] do
        attacker =
          CombatTestHelper.create_player_combatant(weapon_type: weapon_type)
          |> with_equip_modifiers(%{splash_range: 1})

        assert EquipmentBonuses.splash_range(attacker) == 1
      end
    end

    test "returns 0 without the bonus and for mobs" do
      assert EquipmentBonuses.splash_range(CombatTestHelper.create_player_combatant()) == 0
      assert EquipmentBonuses.splash_range(CombatTestHelper.create_mob_combatant()) == 0
    end

    test "clamps a negative radius to 0" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{splash_range: -2})

      assert EquipmentBonuses.splash_range(attacker) == 0
    end
  end

  describe "coma_race_rate/2" do
    test "adds the matching race and :all signed per-10,000 rates" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:coma_race, :brute} => 1_200,
          {:coma_race, :all} => -200,
          {:coma_race, :demon} => 5_000
        })

      brute = CombatTestHelper.create_mob_combatant(race: :brute)
      demon = CombatTestHelper.create_mob_combatant(race: :demon)

      assert EquipmentBonuses.coma_race_rate(attacker, brute) == 1_000
      assert EquipmentBonuses.coma_race_rate(attacker, demon) == 4_800
    end

    test "returns zero without a matching modifier" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:coma_race, :demon} => 2_000})

      brute = CombatTestHelper.create_mob_combatant(race: :brute)

      assert EquipmentBonuses.coma_race_rate(attacker, brute) == 0

      assert EquipmentBonuses.coma_race_rate(
               CombatTestHelper.create_player_combatant(),
               brute
             ) == 0
    end
  end

  describe "critical_add_race_rate/2" do
    test "adds the matching race and :all signed percentage points" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:critical_add_race, :brute} => 12,
          {:critical_add_race, :all} => -3,
          {:critical_add_race, :demon} => 50
        })

      brute = CombatTestHelper.create_mob_combatant(race: :brute)
      demon = CombatTestHelper.create_mob_combatant(race: :demon)

      assert EquipmentBonuses.critical_add_race_rate(attacker, brute) == 9
      assert EquipmentBonuses.critical_add_race_rate(attacker, demon) == 47
    end

    test "returns zero without matching modifiers" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:critical_add_race, :demon} => 20})

      defender = CombatTestHelper.create_mob_combatant(race: :brute)

      assert EquipmentBonuses.critical_add_race_rate(attacker, defender) == 0

      assert EquipmentBonuses.critical_add_race_rate(
               CombatTestHelper.create_player_combatant(),
               defender
             ) == 0
    end
  end

  describe "add_skill_blow/2" do
    test "reads only the named skill's folded signed distance" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:add_skill_blow, 18} => -2,
          {:add_skill_blow, 19} => 5,
          {:add_skill_blow, :all} => 99
        })

      assert EquipmentBonuses.add_skill_blow(attacker, 18) == -2
      assert EquipmentBonuses.add_skill_blow(attacker, 19) == 5
      assert EquipmentBonuses.add_skill_blow(attacker, 20) == 0
      assert EquipmentBonuses.add_skill_blow(CombatTestHelper.create_player_combatant(), 18) == 0
    end
  end

  defp with_equip_modifiers(combatant, modifiers) do
    %{combatant | equip_modifiers: modifiers}
  end
end
