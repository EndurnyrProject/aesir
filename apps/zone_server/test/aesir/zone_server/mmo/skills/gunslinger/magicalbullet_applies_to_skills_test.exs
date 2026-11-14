defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.MagicalbulletAppliesToSkillsTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @moduletag game_mode: :renewal

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(RaceModifiers)
    Mimic.copy(DamageInputs)

    CombatTestHelper.stub_element_coefficient(fn _, _, _, _ -> 1.0 end)
    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
    stub(RaceModifiers, :player_race, fn -> :human end)
    stub(ModifierCalculator, :get_battle_modifiers, fn _, _ -> %{} end)

    attacker = CombatTestHelper.create_player_combatant(flat_atk: 101)
    stats = Map.merge(attacker.combat_stats, %{matk_min: 100, matk_max: 101})

    %{
      attacker: %{attacker | combat_stats: stats},
      defender: CombatTestHelper.create_mob_combatant(def: 0, soft_def: 0)
    }
  end

  defp skill_hit(attacker, defender) do
    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(attacker, defender,
        skill_id: 515,
        skill_ratio: 200,
        skip_crit: true
      )

    damage
  end

  test "a held status adds its term to a weapon skill's weapon ATK", ctx do
    bare = skill_hit(ctx.attacker, ctx.defender)
    :ok = StatusStorage.apply_status(:player, ctx.attacker.unit_id, :sc_magicalbullet, val1: 1)

    assert skill_hit(ctx.attacker, ctx.defender) - bare == 200
  end

  test "the term is rolled once per hit", ctx do
    :ok = StatusStorage.apply_status(:player, ctx.attacker.unit_id, :sc_magicalbullet, val1: 1)
    expect(DamageInputs, :magical_bullet_atk, fn _, _ -> 100 end)
    expect(DamageInputs, :magical_bullet_atk, fn _, _ -> 0 end)

    first = skill_hit(ctx.attacker, ctx.defender)
    second = skill_hit(ctx.attacker, ctx.defender)

    assert first - second == 200
  end
end
