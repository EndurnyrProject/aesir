defmodule Aesir.ZoneServer.Mmo.Combat.ElementStageTest do
  @moduledoc """
  Where each physical hit takes its attribute steps (battle.cpp battle_calc_damage_parts,
  battle_calc_element_damage), observed through the steps the calculator runs.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_private

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)
    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
    stub(ModifierCalculator, :get_battle_modifiers, fn _, _ -> %{} end)
    test_pid = self()

    stub(ElementModifiers, :adjust_damage, fn damage, adjustment ->
      send(test_pid, {:step, adjustment.attack_element, damage})
      call_original(ElementModifiers, :adjust_damage, [damage, adjustment])
    end)

    :ok
  end

  defp steps do
    receive do
      {:step, element, damage} -> [{element, damage} | steps()]
    after
      0 -> []
    end
  end

  defp fire_player(opts \\ []) do
    CombatTestHelper.create_player_combatant(
      Keyword.merge([weapon_type: :dagger, weapon_element: :fire, flat_atk: 7], opts)
    )
  end

  @tag game_mode: :renewal
  test "renewal attributes status, weapon then equipment ATK of both hands" do
    attacker = fire_player()
    status = attacker.combat_stats.physical_attack.status_atk
    defender = CombatTestHelper.create_mob_combatant(def: 0, element: {:neutral, 1})

    assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    # Without a left weapon the left hand's components keep its neutral element.
    assert [
             {:neutral, ^status},
             {:neutral, ^status},
             {:fire, _right_weapon},
             {:neutral, 0},
             {:fire, 7},
             {:neutral, 7}
           ] = steps()
  end

  @tag game_mode: :renewal
  test "renewal doubles right-hand status ATK after its attribute step" do
    attacker = fire_player(str: 14, flat_atk: 0)
    status = attacker.combat_stats.physical_attack.status_atk
    ghost = CombatTestHelper.create_mob_combatant(def: 0, vit: 0, element: {:ghost, 1})
    neutral = CombatTestHelper.create_mob_combatant(def: 0, vit: 0, element: {:neutral, 1})

    {:ok, %{damage: against_ghost}} =
      DamageCalculator.calculate_damage(attacker, ghost, skip_crit: true, element: :neutral)

    {:ok, %{damage: against_neutral}} =
      DamageCalculator.calculate_damage(attacker, neutral, skip_crit: true, element: :neutral)

    # Neutral against Ghost 1 is 90: each status step loses div(status * 10, 100)
    # before the doubling, and the weapon step loses its own share.
    lost = 2 * div(status * 10, 100)
    assert against_neutral - against_ghost >= lost
  end

  @tag game_mode: :pre_renewal
  test "classic takes one attribute step after defense" do
    attacker = fire_player()
    defender = CombatTestHelper.create_mob_combatant(def: 0, element: {:earth, 1})

    assert {:ok, %{damage: damage}} =
             DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    assert [{:fire, before}] = steps()
    assert damage == div(before * 150, 100)
  end

  @tag game_mode: :pre_renewal
  test "classic Magnum Break's share takes its own fire step on a player hit" do
    stub(ModifierCalculator, :get_battle_modifiers, fn
      :player, _id -> %{{:pseudo_element_atk, :fire} => 20}
      _type, _id -> %{}
    end)

    attacker = CombatTestHelper.create_player_combatant(weapon_element: :neutral)
    defender = CombatTestHelper.create_mob_combatant(def: 0, element: {:earth, 1})

    assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)
    assert [{:neutral, _hit}, {:fire, _share}] = steps()
  end

  test "a monster's basic attack takes no attribute step" do
    attacker = CombatTestHelper.create_mob_combatant(unit_id: 3001, element: {:fire, 1})

    defender =
      CombatTestHelper.create_player_combatant(unit_id: 1001) |> Map.put(:element, {:neutral, 1})

    assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)
    assert steps() == []
  end

  test "a monster's skill takes its element after defense" do
    attacker =
      CombatTestHelper.create_mob_combatant(unit_id: 3001, element: {:fire, 1})
      |> Map.update!(:weapon, &%{&1 | element: :fire})

    defender =
      CombatTestHelper.create_player_combatant(unit_id: 1001) |> Map.put(:element, {:neutral, 1})

    assert {:ok, _} =
             DamageCalculator.calculate_damage(attacker, defender, skip_crit: true, skill_id: 5)

    assert [{:fire, _}] = steps()
  end

  test "Cart Revolution takes a forced neutral step after its weapon element" do
    attacker = fire_player()
    defender = CombatTestHelper.create_mob_combatant(def: 0, element: {:ghost, 1})

    assert {:ok, _} =
             DamageCalculator.calculate_damage(attacker, defender, skip_crit: true, skill_id: 153)

    assert {:neutral, _} = List.last(steps())
  end

  @tag game_mode: :pre_renewal
  test "classic Envenom adds its ATK after the step and takes its element again" do
    attacker = fire_player()
    defender = CombatTestHelper.create_mob_combatant(def: 0, element: {:neutral, 1})

    assert {:ok, _} =
             DamageCalculator.calculate_damage(attacker, defender,
               skip_crit: true,
               skill_id: 52,
               element: :poison,
               envenom_atk: 75
             )

    assert [{:poison, first}, {:poison, second}] = steps()
    assert second == first + 75
  end

  test "an immune element deals 0 with no minimum; renewal status ATK stays neutral" do
    attacker = CombatTestHelper.create_player_combatant(weapon_element: :holy)
    status = attacker.combat_stats.physical_attack.status_atk
    defender = CombatTestHelper.create_mob_combatant(def: 0, vit: 0, element: {:holy, 1})

    assert {:ok, %{damage: damage}} =
             DamageCalculator.calculate_damage(attacker, defender,
               skip_crit: true,
               element: :holy
             )

    case GameMode.mode() do
      :renewal -> assert damage == 2 * status
      :pre_renewal -> assert damage == 0
    end
  end
end
