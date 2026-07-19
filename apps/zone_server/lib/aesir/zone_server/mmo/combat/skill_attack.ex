defmodule Aesir.ZoneServer.Mmo.Combat.SkillAttack do
  @moduledoc """
  Physical (BF_WEAPON) and misc (BF_MISC) offensive skill paths: single-target
  skill strikes, ground-centered physical splashes, and trap hits/splashes.
  """

  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting

  @doc """
  Executes a single-target offensive skill from a caster against a target.

  Reuses the melee range check and the unified damage calculator (passing the
  skill's ratio), broadcasts a ZC_NOTIFY_SKILL packet, then applies damage.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll (most skills don't crit)
    - `:bonus_atk` - flat ATK added after the skill ratio, before defense
    - `:fixed_damage` - deal exactly this value, bypassing weapon/defense/flee
    - `:hit_count` - number of hits to deliver, each rolling its own damage (default `1`)
    - `:element` - forces the attack element for this hit, overriding the
      weapon element (e.g. Envenom's poison, Sand Attack's earth)

  ## Returns
    - :ok if the skill connected
    - {:error, reason} if the target was invalid, friendly, dead, or out of range
  """
  @spec execute_skill_attack(struct(), integer(), keyword()) :: :ok | {:error, atom()}
  def execute_skill_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    hits = Keyword.get(opts, :hit_count, 1)

    calc_opts =
      Keyword.take(opts, [
        :skill_ratio,
        :skip_crit,
        :bonus_atk,
        :fixed_damage,
        :element,
        :skill_id
      ])

    # NOTE: skills always connect here; skill miss/flee isn't modeled yet.
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate(attacker, target, projectile?: true),
         :ok <- Targeting.validate_enemy(attacker, target) do
      Enum.each(1..hits//1, fn _ ->
        apply_skill_damage(
          attacker,
          target_type,
          target_pid,
          target,
          skill_id,
          skill_level,
          calc_opts
        )
      end)

      :ok
    end
  end

  @doc """
  Executes a self/ground-centered splash skill against every offensive target in
  `radius` cells of `{x, y}`.

  Selects targets via `SplashTargets.select/4`, then runs each through the
  shared single-target damage path **without** the per-target attack-range
  gate — the radius already bounds the hit set. Returns the list of hit target
  ids, consumed by knockback.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll
  """
  @spec execute_splash_attack(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_splash_attack(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    calc_opts = Keyword.take(opts, [:skill_ratio, :skip_crit, :skill_id])

    attacker.map_name
    |> SplashTargets.select(center, radius, attacker)
    |> Enum.flat_map(fn {_unit_type, target_id} ->
      with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
           target <- target_state.__struct__.to_combatant(target_state),
           :ok <-
             apply_skill_damage(
               attacker,
               target_type,
               target_pid,
               target,
               skill_id,
               skill_level,
               calc_opts
             ) do
        [target_id]
      else
        _ -> []
      end
    end)
  end

  @doc """
  Executes a single-target BF_MISC skill (trap) from a caster against a target.

  Routes the caller-supplied `:base_damage` through `MiscDamageCalculator`
  (element + hard-DEF, soft-DEF/MDEF ignored), broadcasts a `ZC_NOTIFY_SKILL`
  packet, then applies the misc damage. Unlike the magic path there is no
  caster-target range check: a trap fires on contact regardless of where its
  owner stands. Hostility (owner/ally exclusion) is decided by the trap's
  `on_touch` before this is called.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:base_damage` - the skill's per-level base damage (required)
    - `:element` - the skill's attack element (default `:neutral`)
  """
  @spec execute_misc_attack(struct(), integer(), keyword()) :: :ok | {:error, atom()}
  def execute_misc_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)

    apply_misc_hit(attacker, target_id, skill_id, skill_level, element, base_damage)
  end

  @doc """
  Executes a center+radius BF_MISC splash (Blast Mine) against every offensive
  target in range.

  Mirrors `execute_magic_splash/4` but routes each target through
  `MiscDamageCalculator` with the caller-supplied `:base_damage`. Returns the
  list of hit target ids.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:base_damage` - the skill's per-level base damage (required)
    - `:element` - the skill's attack element (default `:neutral`)
  """
  @spec execute_misc_splash(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_misc_splash(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)

    targets = SplashTargets.select(attacker.map_name, center, radius, attacker)

    Enum.flat_map(targets, fn {_unit_type, target_id} ->
      case apply_misc_hit(attacker, target_id, skill_id, skill_level, element, base_damage) do
        :ok -> [target_id]
        _ -> []
      end
    end)
  end

  defp apply_misc_hit(attacker, target_id, skill_id, skill_level, element, base_damage) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Targeting.validate_enemy(attacker, target),
         {:ok, %{damage: damage}} <-
           MiscDamageCalculator.calculate_misc_damage(attacker, target,
             base_damage: base_damage,
             element: element
           ) do
      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage
        )

      DamageApplication.broadcast_nearby(target, packet)

      hit_info = %{
        dmg_type: :misc,
        is_short: false,
        element: element,
        skill_id: skill_id,
        skill_level: skill_level
      }

      DamageApplication.apply_unit_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        hit_info,
        attacker.unit_id
      )

      :ok
    end
  end

  defp apply_skill_damage(
         attacker,
         target_type,
         target_pid,
         target,
         skill_id,
         skill_level,
         calc_opts
       ) do
    with {:ok, damage_result} <- DamageCalculator.calculate_damage(attacker, target, calc_opts) do
      packet =
        PacketFactory.build_skill_damage_packet(
          attacker,
          target,
          skill_id,
          skill_level,
          damage_result
        )

      DamageApplication.broadcast_nearby(target, packet)

      hit_info = %{
        dmg_type: :physical,
        is_short: attacker.attack_range <= 3,
        element: :neutral,
        skill_id: skill_id,
        skill_level: skill_level
      }

      DamageApplication.apply_unit_damage(
        target_type,
        target_pid,
        target.unit_id,
        damage_result.damage,
        hit_info,
        attacker.unit_id
      )

      :ok
    end
  end
end
