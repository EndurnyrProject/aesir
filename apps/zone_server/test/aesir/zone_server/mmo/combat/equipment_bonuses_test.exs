defmodule Aesir.ZoneServer.Mmo.Combat.EquipmentBonusesTest do
  @moduledoc """
  Tests for the pure equipment-bonus read surface used by combat.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.CombatTestHelper
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
               size: 10
             }
    end

    test "empty equip_modifiers returns all zeros" do
      defender = CombatTestHelper.create_mob_combatant()
      attacker = CombatTestHelper.create_player_combatant()

      assert EquipmentBonuses.damage_taken_rates(defender, attacker, :neutral) == %{
               race_class: 0,
               element: 0,
               size: 0
             }
    end
  end

  describe "magic_attack_rates/4" do
    test "sums magic_add* families plus magic_atk_ele and skill" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:magic_addrace, :brute} => 12,
          {:magic_addrace, :all} => 3,
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
               element_target: 8,
               size: 11,
               atk_ele: 20,
               skill: 15
             }
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
               element_target: 0,
               size: 0,
               atk_ele: 0,
               skill: 0
             }
    end
  end

  describe "ignore_def_rate/2" do
    test "sums specific race and :all" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_def_race, :brute} => 30,
          {:ignore_def_race, :all} => 10
        })

      assert EquipmentBonuses.ignore_def_rate(attacker, :brute) == 40
    end

    test "caps at 100" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_def_race, :brute} => 80,
          {:ignore_def_race, :all} => 80
        })

      assert EquipmentBonuses.ignore_def_rate(attacker, :brute) == 100
    end

    test "empty equip_modifiers returns 0" do
      attacker = CombatTestHelper.create_player_combatant()

      assert EquipmentBonuses.ignore_def_rate(attacker, :brute) == 0
    end
  end

  describe "ignore_mdef_rate/2" do
    test "sums specific race and :all" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_mdef_race, :brute} => 30,
          {:ignore_mdef_race, :all} => 10
        })

      assert EquipmentBonuses.ignore_mdef_rate(attacker, :brute) == 40
    end

    test "caps at 100" do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_equip_modifiers(%{
          {:ignore_mdef_race, :brute} => 90,
          {:ignore_mdef_race, :all} => 90
        })

      assert EquipmentBonuses.ignore_mdef_rate(attacker, :brute) == 100
    end

    test "empty equip_modifiers returns 0" do
      attacker = CombatTestHelper.create_player_combatant()

      assert EquipmentBonuses.ignore_mdef_rate(attacker, :brute) == 0
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

  defp with_equip_modifiers(combatant, modifiers) do
    %{combatant | equip_modifiers: modifiers}
  end
end
