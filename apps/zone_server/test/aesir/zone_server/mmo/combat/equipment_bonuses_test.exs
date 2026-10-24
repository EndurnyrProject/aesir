defmodule Aesir.ZoneServer.Mmo.Combat.EquipmentBonusesTest do
  @moduledoc """
  Tests for the pure equipment-bonus read surface used by combat.
  """

  use ExUnit.Case, async: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses

  describe "physical_attack_cardfix/4" do
    setup do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> Map.put(:dragonology_level, 1)
        |> with_equip_modifiers(%{
          {:addele, :earth} => 1,
          {:left_addele, :earth} => 2,
          {:arrow_addele, :earth} => 4,
          {:addrace, :dragon} => 10,
          {:left_addrace, :all} => 20,
          {:arrow_addrace, :dragon} => 40,
          {:addsize, :large} => 100,
          {:left_addsize, :large} => 200,
          {:arrow_addsize, :all} => 400,
          {:addrace2, :goblin} => 3,
          {:left_addrace2, :kobold} => 5,
          {:addclass, :boss} => 7,
          {:left_addclass, :boss} => 8,
          {:arrow_addclass, :all} => 9,
          {:add_damage_class, 1_002} => 11,
          {:left_add_damage_class, 1_002} => 13,
          short_atk_rate: 17,
          long_atk_rate: 19
        })

      defender =
        CombatTestHelper.create_mob_combatant(
          race: :dragon,
          size: :large,
          monster_id: 1_002,
          class: :boss
        )
        |> Map.merge(%{element: {:earth, 1}, race2: [:goblin, :kobold]})

      %{attacker: attacker, defender: defender}
    end

    defp attack_opts(overrides),
      do:
        Map.merge(
          %{arrow?: false, ranged?: false, range_rates?: false, attacker_modifiers: %{}},
          overrides
        )

    test "a melee right hand sums both hands as element, race, size, each group, class", ctx do
      assert EquipmentBonuses.physical_attack_cardfix(
               ctx.attacker,
               ctx.defender,
               :right_hand,
               attack_opts(%{})
             ) ==
               [1 + 2, 10 + 20 + 4, 100 + 200, 3, 5, 7 + 8, 11]
    end

    test "an arrow hit reads the right hand and ammunition as race, element, size, groups, class",
         ctx do
      assert EquipmentBonuses.physical_attack_cardfix(
               ctx.attacker,
               ctx.defender,
               :right_hand,
               attack_opts(%{arrow?: true})
             ) == [10 + 40 + 4, 1 + 4, 100 + 400, 3, 7 + 9, 11]
    end

    test "the range rate the hit's range selects joins only where the mode adds it", ctx do
      melee = attack_opts(%{range_rates?: true})
      long = attack_opts(%{range_rates?: true, ranged?: true})

      assert List.last(
               EquipmentBonuses.physical_attack_cardfix(
                 ctx.attacker,
                 ctx.defender,
                 :right_hand,
                 melee
               )
             ) == 17

      assert List.last(
               EquipmentBonuses.physical_attack_cardfix(
                 ctx.attacker,
                 ctx.defender,
                 :right_hand,
                 long
               )
             ) == 19
    end

    test "the left hand takes only its own per-monster damage bonus", ctx do
      assert EquipmentBonuses.physical_attack_cardfix(
               ctx.attacker,
               ctx.defender,
               :left_hand,
               attack_opts(%{})
             ) ==
               [13]
    end
  end

  describe "physical_defense_cardfix/3" do
    test "orders the resists and adds the left element only when given" do
      attacker =
        CombatTestHelper.create_mob_combatant(race: :brute, size: :small, monster_id: 1_002)
        |> Map.merge(%{element: {:water, 1}, race2: [:goblin]})

      defender =
        CombatTestHelper.create_player_combatant()
        |> Map.put(:faith_level, 1)
        |> with_equip_modifiers(%{
          {:subele, :fire} => 1,
          {:subele, :holy} => 2,
          {:sub_def_ele, :water} => 4,
          {:subsize, :small} => 8,
          {:subrace2, :goblin} => 16,
          {:subrace, :brute} => 32,
          {:subclass, :normal} => 64,
          {:add_def_monster, 1_002} => 3,
          near_atk_def: 5,
          long_atk_def: 6
        })

      opts = %{
        elements: [:fire, :holy],
        ignore_element?: false,
        status_modifiers: %{phys_damage_reduction: 7},
        attack_flag: 0,
        ranged?: false
      }

      assert EquipmentBonuses.physical_defense_cardfix(defender, attacker, opts) ==
               [1, 2 + 5, 4, 8, 16, 32, 64, 3, 5, 7]

      assert EquipmentBonuses.physical_defense_cardfix(defender, attacker, %{
               opts
               | elements: [:fire],
                 ignore_element?: true,
                 ranged?: true
             }) == [8, 16, 32, 64, 3, 6, 7]
    end
  end

  describe "percent_atk_rate/2" do
    test "renewal sums the equipment rate with the status script rate; classic reads 0" do
      attacker = with_equip_modifiers(CombatTestHelper.create_player_combatant(), %{atk_rate: 10})

      assert EquipmentBonuses.percent_atk_rate(attacker, %{bonus_atk_rate: 15}) ==
               mode_value(25, 0)

      assert EquipmentBonuses.percent_atk_rate(attacker, %{}) == mode_value(10, 0)
    end
  end

  describe "attack_rates/4" do
    test "secondary monster groups add physical and magic attack bonuses" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:addrace2, :goblin} => 20, {:magic_addrace2, :goblin} => 30})

      defender = %{CombatTestHelper.create_mob_combatant() | race2: [:goblin]}

      assert EquipmentBonuses.magic_attack_rates(attacker, defender, nil, :neutral) == %{
               race: 0,
               race2: 30,
               class: 0,
               element_target: 0,
               size: 0,
               atk_ele: 0,
               skill: 0
             }
    end

    test "empty secondary monster groups do not match exact bonuses" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:addrace2, :goblin} => 20, {:magic_addrace2, :goblin} => 30})

      defender = %{CombatTestHelper.create_mob_combatant() | race2: []}

      assert EquipmentBonuses.magic_attack_rates(attacker, defender, nil, :neutral) == %{
               race: 0,
               race2: 0,
               class: 0,
               element_target: 0,
               size: 0,
               atk_ele: 0,
               skill: 0
             }
    end

    test "def_monster_rate reads only the attacking monster id" do
      defender =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{{:add_def_monster, 1002} => 25})

      matching_mob = CombatTestHelper.create_mob_combatant(monster_id: 1002)
      other_mob = CombatTestHelper.create_mob_combatant(monster_id: 1099)
      player = CombatTestHelper.create_player_combatant()

      assert EquipmentBonuses.def_monster_rate(defender, matching_mob) == 25
      assert EquipmentBonuses.def_monster_rate(defender, other_mob) == 0
      assert EquipmentBonuses.def_monster_rate(defender, player) == 0
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
               race2: 0,
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
               race2: 0,
               class: 0,
               element_target: 0,
               size: 0,
               atk_ele: 0,
               skill: 0
             }
    end
  end

  test "magic defense reads retain separate groups while shared defense keeps its contract" do
    attacker = %{
      CombatTestHelper.create_mob_combatant(race: :demon, class: :boss)
      | race2: [:goblin]
    }

    defender =
      CombatTestHelper.create_player_combatant()
      |> with_equip_modifiers(%{
        {:subrace, :demon} => 10,
        {:subrace, :all} => 2,
        {:subclass, :boss} => 20,
        {:subrace2, :goblin} => 5,
        {:subele, :fire} => 30,
        {:subsize, :medium} => 7,
        {:sub_skill, 14} => 9
      })

    statuses = %{subrace_demon: 3, subele_fire: 4}
    flag = BattleFlags.build(:magic, :long, true)

    assert EquipmentBonuses.magic_defense_rates(defender, attacker, :fire, statuses, 14, flag) ==
             %{race: 15, race2: 5, class: 20, element: 34, size: 7, skill: 9, magic_size: 0}
  end

  test "magic defense reads its own defensive-element and size resists, never bSubDefEle" do
    attacker = %{
      CombatTestHelper.create_player_combatant()
      | element: {:earth, 1},
        size: :large
    }

    defender =
      CombatTestHelper.create_player_combatant()
      |> with_equip_modifiers(%{
        {:sub_def_ele, :earth} => 40,
        {:magic_sub_def_ele, :earth} => 12,
        {:magic_sub_def_ele, :all} => 3,
        {:magic_sub_def_ele, :fire} => 50,
        {:subsize, :large} => 7,
        {:magic_subsize, :large} => 10,
        {:magic_subsize, :all} => 2,
        {:magic_subsize, :small} => 30
      })

    flag = BattleFlags.build(:magic, :long, true)

    assert %{element: 15, size: 7, magic_size: 12} =
             EquipmentBonuses.magic_defense_rates(defender, attacker, :neutral, %{}, 14, flag)
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

  describe "non_crit_atk_rate/1" do
    test "reads the signed equipment rate for any weapon and zero for mobs" do
      for weapon_type <- [:bow, :sword] do
        attacker =
          [weapon_type: weapon_type]
          |> CombatTestHelper.create_player_combatant()
          |> with_equip_modifiers(%{non_crit_atk_rate: -15})

        assert EquipmentBonuses.non_crit_atk_rate(attacker) == -15
      end

      assert EquipmentBonuses.non_crit_atk_rate(CombatTestHelper.create_mob_combatant()) == 0
    end
  end

  describe "perfect_hit_rate/1" do
    test "combines the strongest base rate with the additive rate for every weapon range" do
      for weapon_type <- [:sword, :bow] do
        attacker =
          CombatTestHelper.create_player_combatant(weapon_type: weapon_type)
          |> with_equip_modifiers(%{perfect_hit_rate: 25, perfect_hit: 15})

        assert EquipmentBonuses.perfect_hit_rate(attacker) == 40
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

  defp mode_value(renewal, classic),
    do: if(GameMode.mode() == :renewal, do: renewal, else: classic)

  defp with_equip_modifiers(combatant, modifiers) do
    %{combatant | equip_modifiers: modifiers}
  end
end
