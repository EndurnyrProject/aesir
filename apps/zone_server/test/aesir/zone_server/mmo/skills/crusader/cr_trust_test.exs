defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrTrustTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrTrust
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

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

  test "is discovered as skill id 248 with maximum level 10" do
    assert {:ok, definition} = Catalog.by_id(248)
    assert definition.name == :cr_trust
    assert definition.max_level == 10
  end

  test "is registered as a passive module" do
    assert CrTrust in Catalog.passive_modules()
  end

  test "grants 200 max HP per level" do
    assert CrTrust.max_hp_bonus(1, %{}) == 200
    assert CrTrust.max_hp_bonus(10, %{}) == 2000
  end

  describe "max HP through the stat pipeline" do
    defp base_stats(learned_skills) do
      %Stats{
        base_stats: %{vit: 1, str: 1, agi: 1, int: 1, dex: 1, luk: 1},
        progression: %{
          base_level: 1,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: learned_skills
        },
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }
    end

    test "Faith lv 5 adds 1000 max HP over an unlearned baseline" do
      without_faith = Stats.calculate_stats(base_stats(%{}))
      with_faith = Stats.calculate_stats(base_stats(%{248 => 5}))

      assert with_faith.derived_stats.max_hp - without_faith.derived_stats.max_hp == 1000
    end

    test "Faith lv 10 adds 2000 max HP over an unlearned baseline" do
      without_faith = Stats.calculate_stats(base_stats(%{}))
      with_faith = Stats.calculate_stats(base_stats(%{248 => 10}))

      assert with_faith.derived_stats.max_hp - without_faith.derived_stats.max_hp == 2000
    end
  end

  describe "holy damage resistance through the families bridge" do
    test "reduces incoming physical holy damage by 5*lv percent" do
      attacker = CombatTestHelper.create_mob_combatant()
      defender_lv0 = %{CombatTestHelper.create_player_combatant() | faith_level: 0}
      defender_lv5 = %{CombatTestHelper.create_player_combatant() | faith_level: 5}

      {:ok, base} =
        DamageCalculator.apply_modifier_pipeline(1000, attacker, defender_lv0, element: :holy)

      {:ok, resisted} =
        DamageCalculator.apply_modifier_pipeline(1000, attacker, defender_lv5, element: :holy)

      assert resisted == base * 0.75
    end

    test "leaves incoming physical non-holy damage unaffected" do
      attacker = CombatTestHelper.create_mob_combatant()
      defender_lv0 = %{CombatTestHelper.create_player_combatant() | faith_level: 0}
      defender_lv5 = %{CombatTestHelper.create_player_combatant() | faith_level: 5}

      {:ok, unaffected_lv0} =
        DamageCalculator.apply_modifier_pipeline(1000, attacker, defender_lv0, element: :fire)

      {:ok, unaffected_lv5} =
        DamageCalculator.apply_modifier_pipeline(1000, attacker, defender_lv5, element: :fire)

      assert unaffected_lv0 == unaffected_lv5
    end

    test "reduces incoming magic holy damage by 5*lv percent" do
      attacker = with_matk(CombatTestHelper.create_mob_combatant(), 1000)
      defender_lv0 = with_mdef(CombatTestHelper.create_player_combatant(), 0, 0)
      defender_lv5 = %{defender_lv0 | faith_level: 5}

      assert {:ok, %{damage: base}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender_lv0,
                 element: :holy
               )

      assert {:ok, %{damage: resisted}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender_lv5,
                 element: :holy
               )

      assert resisted == trunc(base * 0.75)
    end

    test "leaves incoming magic non-holy damage unaffected" do
      attacker = with_matk(CombatTestHelper.create_mob_combatant(), 1000)
      defender_lv0 = with_mdef(CombatTestHelper.create_player_combatant(), 0, 0)
      defender_lv5 = %{defender_lv0 | faith_level: 5}

      assert {:ok, %{damage: unaffected_lv0}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender_lv0,
                 element: :fire
               )

      assert {:ok, %{damage: unaffected_lv5}} =
               MagicDamageCalculator.calculate_magic_damage(attacker, defender_lv5,
                 element: :fire
               )

      assert unaffected_lv0 == unaffected_lv5
    end

    defp with_matk(combatant, matk) do
      %{combatant | combat_stats: Map.put(combatant.combat_stats, :matk, matk)}
    end

    defp with_mdef(combatant, mdef, soft_mdef) do
      combat_stats =
        combatant.combat_stats
        |> Map.put(:mdef, mdef)
        |> Map.put(:soft_mdef, soft_mdef)

      %{combatant | combat_stats: combat_stats, faith_level: 0}
    end
  end
end
