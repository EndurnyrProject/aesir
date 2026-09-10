defmodule Aesir.ZoneServer.Mmo.Skills.Monk.Formulas do
  @moduledoc """
  Pure arithmetic shared by Monk player skills and mob skill archetypes. Functions
  whose value differs between renewal and pre-renewal branch on the booted mode.

  Asura's `:bonus_atk` component feeds the pre-defense
  `Aesir.ZoneServer.Mmo.Combat.DamageCalculator` bonus-atk channel.
  """

  alias Aesir.Commons.GameMode

  @spec trifecta_activation_rate(pos_integer()) :: pos_integer()
  def trifecta_activation_rate(level) do
    case GameMode.mode() do
      :renewal -> 30
      :pre_renewal -> 30 - level
    end
  end

  @spec trifecta_ratio(pos_integer()) :: pos_integer()
  def trifecta_ratio(level), do: 100 + 20 * level

  @spec trifecta_hit_count() :: 3
  def trifecta_hit_count, do: 3

  @spec quadruple_ratio(pos_integer(), boolean()) :: pos_integer()
  def quadruple_ratio(level, knuckle?) do
    case GameMode.mode() do
      :renewal ->
        ratio = 250 + 50 * level
        if knuckle?, do: ratio * 2, else: ratio

      :pre_renewal ->
        150 + 50 * level
    end
  end

  @spec quadruple_hit_count(boolean()) :: 4 | 6
  def quadruple_hit_count(true), do: if(GameMode.mode() == :renewal, do: 6, else: 4)
  def quadruple_hit_count(false), do: 4

  @spec thrust_ratio(pos_integer(), non_neg_integer()) :: pos_integer()
  def thrust_ratio(level, strength) do
    case GameMode.mode() do
      :renewal -> 550 + 50 * level + strength
      :pre_renewal -> 240 + 60 * level
    end
  end

  @spec thrust_hit_count() :: 1
  def thrust_hit_count, do: 1

  @spec occult_ratio(pos_integer(), boolean()) :: pos_integer()
  def occult_ratio(level, rooted?) do
    case GameMode.mode() do
      :renewal ->
        ratio = 100 * level
        if rooted?, do: ratio + div(ratio, 2), else: ratio

      :pre_renewal ->
        100 + 75 * level
    end
  end

  @spec throw_spirit_sphere_ratio(pos_integer(), boolean()) :: pos_integer()
  def throw_spirit_sphere_ratio(level, rooted?) do
    case GameMode.mode() do
      :renewal ->
        ratio = 600 + 200 * level
        if rooted?, do: ratio + div(ratio, 2), else: ratio

      :pre_renewal ->
        100 + 50 * level
    end
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

  @spec fury_regeneration_tick_multiplier() :: 2
  def fury_regeneration_tick_multiplier, do: 2

  @spec mental_strength_damage(non_neg_integer()) :: non_neg_integer()
  def mental_strength_damage(0), do: 0
  def mental_strength_damage(damage), do: max(1, div(damage, 10))

  @spec mental_strength_walk_speed() :: 200
  def mental_strength_walk_speed, do: 200

  @spec mental_strength_aspd_penalty_rate() :: 250
  def mental_strength_aspd_penalty_rate, do: 250

  @spec root_duration(boolean(), pos_integer()) :: pos_integer()
  def root_duration(boss?, root_level) do
    case {GameMode.mode(), boss?} do
      {:renewal, true} -> 2_000
      {:renewal, false} -> 10_000
      {:pre_renewal, _boss?} -> 10_000 * (root_level + 1)
    end
  end

  @type asura_context :: :normal | :root | :combo

  @spec asura_sphere_cost(asura_context(), non_neg_integer()) :: pos_integer()
  def asura_sphere_cost(:normal, _held_spheres), do: 5
  def asura_sphere_cost(:root, _held_spheres), do: 4

  def asura_sphere_cost(:combo, held_spheres) do
    case GameMode.mode() do
      :renewal -> max(held_spheres, 1)
      :pre_renewal -> 4
    end
  end

  @type asura_damage_components :: %{skill_ratio: pos_integer(), bonus_atk: pos_integer()}

  @spec asura_damage_components(pos_integer(), non_neg_integer()) :: asura_damage_components()
  def asura_damage_components(level, current_sp) do
    %{skill_ratio: min(800 + current_sp * 10, 500_000), bonus_atk: 250 + 150 * level}
  end

  @spec asura_recovery_duration() :: pos_integer()
  def asura_recovery_duration, do: if(GameMode.mode() == :renewal, do: 3_000, else: 300_000)

  @spec snap_range() :: 18
  def snap_range, do: 18

  @spec snap_sp_cost() :: 14
  def snap_sp_cost, do: 14

  @spec snap_sphere_cost(boolean()) :: 0 | 1
  def snap_sphere_cost(true), do: 0
  def snap_sphere_cost(false), do: 1

  @spec ki_explosion_ratio() :: pos_integer()
  def ki_explosion_ratio, do: if(GameMode.mode() == :renewal, do: 800, else: 300)

  @spec ki_explosion_hp_cost() :: pos_integer()
  def ki_explosion_hp_cost, do: if(GameMode.mode() == :renewal, do: 200, else: 10)

  @spec ki_explosion_sp_cost() :: pos_integer()
  def ki_explosion_sp_cost, do: if(GameMode.mode() == :renewal, do: 40, else: 20)

  @spec ki_explosion_stun_rate() :: 70
  def ki_explosion_stun_rate, do: 70

  @spec ki_explosion_stun_duration() :: pos_integer()
  def ki_explosion_stun_duration, do: if(GameMode.mode() == :renewal, do: 4_500, else: 5_000)

  @spec occult_sp_cost(pos_integer()) :: pos_integer()
  def occult_sp_cost(level), do: elem({10, 14, 17, 19, 20}, level - 1)

  @spec throw_spirit_sphere_sp_cost(pos_integer()) :: pos_integer()
  def throw_spirit_sphere_sp_cost(level), do: 8 + 4 * level

  @spec throw_spirit_sphere_walk_delay(pos_integer()) :: non_neg_integer()
  def throw_spirit_sphere_walk_delay(level), do: 200 * (level - 1)

  @spec asura_sp_cost() :: 1
  def asura_sp_cost, do: 1

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

  @spec root_profile() :: %{sp_cost: 10, sphere_cost: 1, after_cast_delay: 500, cooldown: 3_000}
  def root_profile, do: %{sp_cost: 10, sphere_cost: 1, after_cast_delay: 500, cooldown: 3_000}
end
