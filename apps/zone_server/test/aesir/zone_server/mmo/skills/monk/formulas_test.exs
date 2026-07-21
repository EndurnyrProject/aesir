defmodule Aesir.ZoneServer.Mmo.Skills.Monk.FormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas

  test "Trifecta has the Renewal 30 percent activation chance at every level" do
    assert Formulas.trifecta_activation_rate(1) == 30
    assert Formulas.trifecta_activation_rate(5) == 30
    assert Formulas.trifecta_activation_rate(10) == 30
  end

  test "shared weapon ratios retain Renewal base-ratio and level arithmetic" do
    assert Formulas.trifecta_ratio(1) == 120
    assert Formulas.trifecta_ratio(5) == 200
    assert Formulas.trifecta_ratio(10) == 300

    assert Formulas.quadruple_ratio(1, false) == 300
    assert Formulas.quadruple_ratio(3, true) == 800
    assert Formulas.quadruple_ratio(5, false) == 500

    assert Formulas.thrust_ratio(1, 0) == 600
    assert Formulas.thrust_ratio(3, 47) == 747
    assert Formulas.thrust_ratio(5, 99) == 899

    assert Formulas.occult_ratio(1, false) == 100
    assert Formulas.occult_ratio(3, true) == 450
    assert Formulas.occult_ratio(5, false) == 500

    assert Formulas.throw_spirit_sphere_ratio(1, false) == 800
    assert Formulas.throw_spirit_sphere_ratio(3, true) == 1_800
    assert Formulas.throw_spirit_sphere_ratio(5, false) == 1_600
  end

  test "hit-count helpers retain the local default one-sphere multi-hit throw" do
    assert Formulas.trifecta_hit_count() == 3
    assert Formulas.quadruple_hit_count(false) == 4
    assert Formulas.quadruple_hit_count(true) == 6
    assert Formulas.thrust_hit_count() == 1

    assert Formulas.throw_spirit_sphere_cost() == 1
    assert Formulas.throw_spirit_sphere_hit_count() == 5
  end

  test "passive and spirit helpers preserve Renewal integer arithmetic" do
    assert Formulas.iron_fists_attack_bonus(1) == 3
    assert Formulas.iron_fists_attack_bonus(10) == 30

    assert Formulas.dodge_flee_bonus(1) == 1
    assert Formulas.dodge_flee_bonus(3) == 4
    assert Formulas.dodge_flee_bonus(10) == 15

    assert Formulas.spiritual_cadence_regeneration(1, 499, 499) == {4, 2}
    assert Formulas.spiritual_cadence_regeneration(3, 1_234, 2_345) == {19, 20}
    assert Formulas.spiritual_cadence_regeneration(5, 10_000, 10_000) == {120, 110}

    assert Formulas.spirit_sphere_duration() == 600_000
    assert Formulas.absorb_player_sphere_sp(3) == 21
    assert Formulas.absorb_mob_sp(99) == 198
    assert Formulas.absorb_mob_activation_rate() == 20
  end

  test "Fury and Mental Strength keep their exact status modifiers" do
    assert Formulas.fury_critical_bonus(1) == 100
    assert Formulas.fury_critical_bonus(3) == 150
    assert Formulas.fury_critical_bonus(5) == 200
    assert Formulas.fury_duration() == 180_000
    assert Formulas.fury_regeneration_tick_multiplier() == 2

    assert Formulas.mental_strength_damage(0) == 0
    assert Formulas.mental_strength_damage(9) == 1
    assert Formulas.mental_strength_damage(20) == 2
    assert Formulas.mental_strength_damage(99) == 9
    assert Formulas.mental_strength_walk_speed() == 200
    assert Formulas.mental_strength_aspd_penalty_rate() == 250
    assert Formulas.mental_strength_duration(1) == 30_000
    assert Formulas.mental_strength_duration(3) == 90_000
    assert Formulas.mental_strength_duration(5) == 150_000
  end

  test "Root and Asura preserve their Renewal bonuses, costs, and cap order" do
    assert Formulas.root_wait_duration(1) == 500
    assert Formulas.root_wait_duration(3) == 900
    assert Formulas.root_wait_duration(5) == 1_300
    assert Formulas.root_duration(false) == 10_000
    assert Formulas.root_duration(true) == 2_000

    assert Formulas.asura_sphere_cost(:normal, 0) == 5
    assert Formulas.asura_sphere_cost(:root, 0) == 4
    assert Formulas.asura_sphere_cost(:combo, 0) == 1
    assert Formulas.asura_sphere_cost(:combo, 1) == 1
    assert Formulas.asura_sphere_cost(:combo, 5) == 5

    assert Formulas.asura_damage_components(1, 0) == %{skill_ratio: 800, bonus_atk: 400}
    assert Formulas.asura_damage_components(3, 123) == %{skill_ratio: 2_030, bonus_atk: 700}

    assert Formulas.asura_damage_components(5, 60_000) == %{
             skill_ratio: 500_000,
             bonus_atk: 1_000
           }

    assert Formulas.asura_recovery_duration() == 3_000
  end

  test "Snap and Ki Explosion expose their Renewal resource and area constants" do
    assert Formulas.snap_range() == 18
    assert Formulas.snap_sp_cost() == 14
    assert Formulas.snap_sphere_cost(false) == 1
    assert Formulas.snap_sphere_cost(true) == 0

    assert Formulas.ki_explosion_ratio() == 800
    assert Formulas.ki_explosion_hp_cost() == 200
    refute Formulas.ki_explosion_can_pay_hp?(200)
    assert Formulas.ki_explosion_can_pay_hp?(201)
    assert Formulas.ki_explosion_sp_cost() == 40
    assert Formulas.ki_explosion_splash_radius() == 1
    assert Formulas.ki_explosion_knockback() == 5
    assert Formulas.ki_explosion_stun_rate() == 70
    assert Formulas.ki_explosion_stun_duration() == 4_500
    assert Formulas.ki_explosion_after_cast_delay() == 2_000
  end

  test "Summon and Ki Translation preserve their sphere cost and timing profiles" do
    assert Formulas.summon_spirit_sphere_profile() == %{
             sp_cost: 8,
             cast_time: 500,
             fixed_cast_time: 500,
             sphere_duration: 600_000
           }

    assert Formulas.ki_translation_profile() == %{
             sp_cost: 40,
             sphere_cost: 1,
             cast_time: 1_000,
             fixed_cast_time: 1_000,
             after_cast_delay: 1_000,
             transferred_sphere_duration: 600_000
           }
  end

  test "Occult and Throw Spirit Sphere retain their level cost and delay tables" do
    assert Formulas.occult_sp_cost(1) == 10
    assert Formulas.occult_sp_cost(3) == 17
    assert Formulas.occult_sp_cost(5) == 20

    assert Formulas.throw_spirit_sphere_sp_cost(1) == 12
    assert Formulas.throw_spirit_sphere_sp_cost(3) == 20
    assert Formulas.throw_spirit_sphere_sp_cost(5) == 28
    assert Formulas.throw_spirit_sphere_walk_delay(1) == 0
    assert Formulas.throw_spirit_sphere_walk_delay(3) == 400
    assert Formulas.throw_spirit_sphere_walk_delay(5) == 800
  end

  test "combo and Asura level tables retain their source arithmetic" do
    assert Formulas.quadruple_sp_cost(1) == 5
    assert Formulas.quadruple_sp_cost(3) == 7
    assert Formulas.quadruple_sp_cost(5) == 9
    assert Formulas.thrust_sp_cost(1) == 3
    assert Formulas.thrust_sp_cost(3) == 5
    assert Formulas.thrust_sp_cost(5) == 7

    assert Formulas.asura_timing(1) == %{cast_time: 2_000, after_cast_delay: 3_000}
    assert Formulas.asura_timing(3) == %{cast_time: 1_500, after_cast_delay: 2_000}
    assert Formulas.asura_timing(5) == %{cast_time: 1_000, after_cast_delay: 1_000}
    assert Formulas.asura_fixed_cast_time(1) == 2_000
    assert Formulas.asura_fixed_cast_time(3) == 1_500
    assert Formulas.asura_fixed_cast_time(5) == 1_000
    assert Formulas.asura_sp_cost() == 1
  end

  test "fixed profiles cover the remaining scoped Monk skill costs and timings" do
    assert Formulas.absorb_spirit_sphere_profile() == %{sp_cost: 5, fixed_cast_time: 500}

    assert Formulas.occult_timing() == %{
             cast_time: 500,
             fixed_cast_time: 500,
             after_cast_delay: 500
           }

    assert Formulas.throw_spirit_sphere_timing() == %{
             cast_time: 500,
             fixed_cast_time: 500,
             after_cast_delay: 500,
             cooldown: 1_000
           }

    assert Formulas.mental_strength_profile() == %{
             sp_cost: 200,
             sphere_cost: 5,
             cast_time: 2_500,
             fixed_cast_time: 2_500
           }

    assert Formulas.root_profile() == %{
             sp_cost: 10,
             sphere_cost: 1,
             after_cast_delay: 500,
             cooldown: 3_000
           }

    assert Formulas.fury_profile() == %{sp_cost: 15, sphere_cost: 5}
  end
end
