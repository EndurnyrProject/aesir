defmodule Aesir.ZoneServer.Mmo.Skills.Monk.Formulas do
  @moduledoc """
  Pure Renewal arithmetic shared by Monk player skills and mob skill archetypes.

  Asura's `:bonus_atk` component feeds the pre-defense
  `Aesir.ZoneServer.Mmo.Combat.DamageCalculator` bonus-atk channel.
  """

  @spec trifecta_activation_rate(pos_integer()) :: 30
  def trifecta_activation_rate(_level), do: 30

  @spec trifecta_ratio(pos_integer()) :: pos_integer()
  def trifecta_ratio(level), do: 100 + 20 * level

  @spec trifecta_hit_count() :: 3
  def trifecta_hit_count, do: 3

  @spec quadruple_ratio(pos_integer(), boolean()) :: pos_integer()
  def quadruple_ratio(level, knuckle?) do
    ratio = 250 + 50 * level
    if knuckle?, do: ratio * 2, else: ratio
  end

  @spec quadruple_hit_count(boolean()) :: 4 | 6
  def quadruple_hit_count(true), do: 6
  def quadruple_hit_count(false), do: 4

  @spec thrust_ratio(pos_integer(), non_neg_integer()) :: pos_integer()
  def thrust_ratio(level, strength), do: 550 + 50 * level + strength

  @spec thrust_hit_count() :: 1
  def thrust_hit_count, do: 1

  @spec occult_ratio(pos_integer(), boolean()) :: pos_integer()
  def occult_ratio(level, rooted?) do
    ratio = 100 * level
    if rooted?, do: ratio + div(ratio, 2), else: ratio
  end

  @spec throw_spirit_sphere_ratio(pos_integer(), boolean()) :: pos_integer()
  def throw_spirit_sphere_ratio(level, rooted?) do
    ratio = 600 + 200 * level
    if rooted?, do: ratio + div(ratio, 2), else: ratio
  end

  @spec throw_spirit_sphere_cost() :: 1
  def throw_spirit_sphere_cost, do: 1

  @spec throw_spirit_sphere_hit_count() :: 5
  def throw_spirit_sphere_hit_count, do: 5

  @spec iron_fists_attack_bonus(pos_integer()) :: pos_integer()
  def iron_fists_attack_bonus(level), do: 3 * level

  @spec dodge_flee_bonus(pos_integer()) :: non_neg_integer()
  def dodge_flee_bonus(level), do: div(3 * level, 2)

  @spec spiritual_cadence_regeneration(pos_integer(), non_neg_integer(), non_neg_integer()) ::
          {non_neg_integer(), non_neg_integer()}
  def spiritual_cadence_regeneration(level, max_hp, max_sp) do
    {4 * level + div(level * max_hp, 500), 2 * level + div(level * max_sp, 500)}
  end

  @spec spirit_sphere_duration() :: 600_000
  def spirit_sphere_duration, do: 600_000

  @spec absorb_player_sphere_sp(non_neg_integer()) :: non_neg_integer()
  def absorb_player_sphere_sp(spheres), do: 7 * spheres

  @spec absorb_mob_sp(non_neg_integer()) :: non_neg_integer()
  def absorb_mob_sp(level), do: 2 * level

  @spec absorb_mob_activation_rate() :: 20
  def absorb_mob_activation_rate, do: 20

  @spec fury_critical_bonus(pos_integer()) :: pos_integer()
  def fury_critical_bonus(level), do: 75 + 25 * level

  @spec fury_duration() :: 180_000
  def fury_duration, do: 180_000

  @spec fury_regeneration_tick_multiplier() :: 2
  def fury_regeneration_tick_multiplier, do: 2

  @spec mental_strength_damage(non_neg_integer()) :: non_neg_integer()
  def mental_strength_damage(0), do: 0
  def mental_strength_damage(damage), do: max(1, div(damage, 10))

  @spec mental_strength_walk_speed() :: 200
  def mental_strength_walk_speed, do: 200

  @spec mental_strength_aspd_penalty_rate() :: 250
  def mental_strength_aspd_penalty_rate, do: 250

  @spec mental_strength_duration(pos_integer()) :: pos_integer()
  def mental_strength_duration(level), do: 30_000 * level

  @spec root_wait_duration(pos_integer()) :: pos_integer()
  def root_wait_duration(level), do: 300 + 200 * level

  @spec root_duration(boolean()) :: 2_000 | 10_000
  def root_duration(true), do: 2_000
  def root_duration(false), do: 10_000

  @type asura_context :: :normal | :root | :combo

  @spec asura_sphere_cost(asura_context(), non_neg_integer()) :: pos_integer()
  def asura_sphere_cost(:normal, _held_spheres), do: 5
  def asura_sphere_cost(:root, _held_spheres), do: 4
  def asura_sphere_cost(:combo, held_spheres), do: max(held_spheres, 1)

  @type asura_damage_components :: %{skill_ratio: pos_integer(), bonus_atk: pos_integer()}

  @spec asura_damage_components(pos_integer(), non_neg_integer()) :: asura_damage_components()
  def asura_damage_components(level, current_sp) do
    %{skill_ratio: min(800 + current_sp * 10, 500_000), bonus_atk: 250 + 150 * level}
  end

  @spec asura_recovery_duration() :: 3_000
  def asura_recovery_duration, do: 3_000

  @spec snap_range() :: 18
  def snap_range, do: 18

  @spec snap_sp_cost() :: 14
  def snap_sp_cost, do: 14

  @spec snap_sphere_cost(boolean()) :: 0 | 1
  def snap_sphere_cost(true), do: 0
  def snap_sphere_cost(false), do: 1

  @spec ki_explosion_ratio() :: 800
  def ki_explosion_ratio, do: 800

  @spec ki_explosion_hp_cost() :: 200
  def ki_explosion_hp_cost, do: 200

  @spec ki_explosion_can_pay_hp?(non_neg_integer()) :: boolean()
  def ki_explosion_can_pay_hp?(current_hp), do: current_hp > ki_explosion_hp_cost()

  @spec ki_explosion_sp_cost() :: 40
  def ki_explosion_sp_cost, do: 40

  @spec ki_explosion_splash_radius() :: 1
  def ki_explosion_splash_radius, do: 1

  @spec ki_explosion_knockback() :: 5
  def ki_explosion_knockback, do: 5

  @spec ki_explosion_stun_rate() :: 70
  def ki_explosion_stun_rate, do: 70

  @spec ki_explosion_stun_duration() :: 4_500
  def ki_explosion_stun_duration, do: 4_500

  @spec ki_explosion_after_cast_delay() :: 2_000
  def ki_explosion_after_cast_delay, do: 2_000

  @spec summon_spirit_sphere_profile() :: %{
          sp_cost: 8,
          cast_time: 500,
          fixed_cast_time: 500,
          sphere_duration: 600_000
        }
  def summon_spirit_sphere_profile do
    %{sp_cost: 8, cast_time: 500, fixed_cast_time: 500, sphere_duration: spirit_sphere_duration()}
  end

  @spec ki_translation_profile() :: %{
          sp_cost: 40,
          sphere_cost: 1,
          cast_time: 1_000,
          fixed_cast_time: 1_000,
          after_cast_delay: 1_000,
          transferred_sphere_duration: 600_000
        }
  def ki_translation_profile do
    %{
      sp_cost: 40,
      sphere_cost: 1,
      cast_time: 1_000,
      fixed_cast_time: 1_000,
      after_cast_delay: 1_000,
      transferred_sphere_duration: spirit_sphere_duration()
    }
  end

  @spec occult_sp_cost(pos_integer()) :: pos_integer()
  def occult_sp_cost(level), do: elem({10, 14, 17, 19, 20}, level - 1)

  @spec throw_spirit_sphere_sp_cost(pos_integer()) :: pos_integer()
  def throw_spirit_sphere_sp_cost(level), do: 8 + 4 * level

  @spec throw_spirit_sphere_walk_delay(pos_integer()) :: non_neg_integer()
  def throw_spirit_sphere_walk_delay(level), do: 200 * (level - 1)

  @spec quadruple_sp_cost(pos_integer()) :: pos_integer()
  def quadruple_sp_cost(level), do: 4 + level

  @spec thrust_sp_cost(pos_integer()) :: pos_integer()
  def thrust_sp_cost(level), do: 2 + level

  @spec asura_timing(pos_integer()) :: %{
          cast_time: pos_integer(),
          after_cast_delay: pos_integer()
        }
  def asura_timing(level) do
    %{cast_time: 2_250 - 250 * level, after_cast_delay: 3_500 - 500 * level}
  end

  @spec asura_fixed_cast_time(pos_integer()) :: pos_integer()
  def asura_fixed_cast_time(level), do: 2_250 - 250 * level

  @spec asura_sp_cost() :: 1
  def asura_sp_cost, do: 1

  @spec absorb_spirit_sphere_profile() :: %{sp_cost: 5, fixed_cast_time: 500}
  def absorb_spirit_sphere_profile, do: %{sp_cost: 5, fixed_cast_time: 500}

  @spec occult_timing() :: %{cast_time: 500, fixed_cast_time: 500, after_cast_delay: 500}
  def occult_timing, do: %{cast_time: 500, fixed_cast_time: 500, after_cast_delay: 500}

  @spec throw_spirit_sphere_timing() :: %{
          cast_time: 500,
          fixed_cast_time: 500,
          after_cast_delay: 500,
          cooldown: 1_000
        }
  def throw_spirit_sphere_timing do
    %{cast_time: 500, fixed_cast_time: 500, after_cast_delay: 500, cooldown: 1_000}
  end

  @spec mental_strength_profile() :: %{
          sp_cost: 200,
          sphere_cost: 5,
          cast_time: 2_500,
          fixed_cast_time: 2_500
        }
  def mental_strength_profile do
    %{sp_cost: 200, sphere_cost: 5, cast_time: 2_500, fixed_cast_time: 2_500}
  end

  @spec root_profile() :: %{sp_cost: 10, sphere_cost: 1, after_cast_delay: 500, cooldown: 3_000}
  def root_profile, do: %{sp_cost: 10, sphere_cost: 1, after_cast_delay: 500, cooldown: 3_000}

  @spec fury_profile() :: %{sp_cost: 15, sphere_cost: 5}
  def fury_profile, do: %{sp_cost: 15, sphere_cost: 5}
end
