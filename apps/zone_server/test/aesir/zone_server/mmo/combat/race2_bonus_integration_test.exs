defmodule Aesir.ZoneServer.Mmo.Combat.Race2BonusIntegrationTest do
  @moduledoc """
  Exercises secondary monster group equipment bonuses through the damage calculators.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)

    stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

    :ok
  end

  test "subrace2 reduces physical damage only from an in-group mob" do
    defender = %{
      CombatTestHelper.create_player_combatant()
      | equip_modifiers: %{{:subrace2, :goblin} => 20}
    }

    in_group = %{CombatTestHelper.create_mob_combatant() | race2: [:goblin]}
    out_of_group = %{CombatTestHelper.create_mob_combatant() | race2: []}

    assert {:ok, 800} = DamageCalculator.apply_modifier_pipeline(1_000, in_group, defender)

    assert {:ok, 1_000.0} =
             DamageCalculator.apply_modifier_pipeline(1_000, out_of_group, defender)
  end

  test "addrace2 raises physical damage against an in-group mob" do
    attacker = %{
      CombatTestHelper.create_player_combatant()
      | equip_modifiers: %{{:addrace2, :goblin} => 20}
    }

    in_group = %{CombatTestHelper.create_mob_combatant() | race2: [:goblin]}
    out_of_group = %{CombatTestHelper.create_mob_combatant() | race2: []}

    assert {:ok, 1_200} = DamageCalculator.apply_modifier_pipeline(1_000, attacker, in_group)

    assert {:ok, 1_000.0} =
             DamageCalculator.apply_modifier_pipeline(1_000, attacker, out_of_group)
  end

  test "magic_addrace2 raises magic damage against an in-group mob" do
    attacker = %{
      CombatTestHelper.create_player_combatant()
      | combat_stats: %{matk: 100, matk_min: 100, matk_max: 100},
        equip_modifiers: %{{:magic_addrace2, :goblin} => 20}
    }

    in_group = %{
      CombatTestHelper.create_mob_combatant()
      | combat_stats: %{mdef: 0, soft_mdef: 0},
        race2: [:goblin]
    }

    out_of_group = %{in_group | race2: []}

    assert {:ok, %{damage: 120}} =
             MagicDamageCalculator.calculate_magic_damage(attacker, in_group)

    assert {:ok, %{damage: 100}} =
             MagicDamageCalculator.calculate_magic_damage(attacker, out_of_group)
  end

  test "subrace2 reduces magic damage only from an in-group attacker" do
    defender = %{
      CombatTestHelper.create_player_combatant()
      | combat_stats: %{mdef: 0, soft_mdef: 0},
        equip_modifiers: %{{:subrace2, :goblin} => 20}
    }

    in_group = %{
      CombatTestHelper.create_mob_combatant()
      | combat_stats: %{matk: 100, matk_min: 100, matk_max: 100},
        race2: [:goblin]
    }

    out_of_group = %{in_group | race2: []}

    assert {:ok, %{damage: 80}} =
             MagicDamageCalculator.calculate_magic_damage(in_group, defender)

    assert {:ok, %{damage: 100}} =
             MagicDamageCalculator.calculate_magic_damage(out_of_group, defender)
  end
end
