defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GrounddriftPreReFlatTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGrounddrift
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @moduletag game_mode: :pre_renewal

  setup :set_mimic_private

  setup do
    Mimic.copy(SkillAttack)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    stub(ModifierCalculator, :get_battle_modifiers, fn _, _ -> %{} end)
    :ok
  end

  defp damage(attacker, opts) do
    defender = CombatTestHelper.create_mob_combatant(def: 0)
    :rand.seed(:exsss, {4, 5, 6})

    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(
        attacker,
        defender,
        [skill_id: 521, skill_level: 10, skill_ratio: 300, skip_crit: true] ++ opts
      )

    damage
  end

  defp group(caster_type, caster_id),
    do: %Group{
      group_id: 1,
      skill_id: 521,
      skill_name: :gs_grounddrift,
      level: 10,
      caster_id: caster_id,
      caster_type: caster_type,
      map_name: "prontera",
      center: {50, 50},
      state: %{element: :neutral, variant: 4, armed_until: 0}
    }

  test "a player's hit adds 50 per level after the ratio" do
    attacker = CombatTestHelper.create_player_combatant(luk: 0, flat_atk: 100)
    assert damage(attacker, late_atk_bonus: 500) - damage(attacker, []) == 500
  end

  test "a player drift passes 50 per level and a mob drift passes nothing" do
    stub_units([player(1000), mob(7)])
    test_pid = self()

    stub(SkillAttack, :execute_field_splash_attack, fn _c, _ctr, _r, _g, opts ->
      send(test_pid, {:flat, opts[:late_atk_bonus], opts[:ignore_flee]})
      []
    end)

    stub(SkillAttack, :execute_splash_attack, fn _c, _ctr, _r, opts ->
      send(test_pid, {:flat, opts[:late_atk_bonus], opts[:ignore_flee]})
      []
    end)

    GsGrounddrift.on_unit_hit(group(:player, 1000), {50, 50}, {:mob, 7}, 0)
    assert_received {:flat, 500, true}
    GsGrounddrift.on_unit_hit(group(:mob, 7), {50, 50}, {:player, 1000}, 0)
    assert_received {:flat, nil, true}
  end

  test "a mob attacker ignores the flat term" do
    attacker = CombatTestHelper.create_mob_combatant(atk: 100)
    assert damage(attacker, late_atk_bonus: 500) == damage(attacker, [])
  end
end
