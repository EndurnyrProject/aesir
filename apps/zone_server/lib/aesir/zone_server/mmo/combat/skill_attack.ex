defmodule Aesir.ZoneServer.Mmo.Combat.SkillAttack do
  @moduledoc """
  Physical (BF_WEAPON) and misc (BF_MISC) offensive skill paths: single-target
  skill strikes, ground-centered physical splashes, line strikes, and trap
  hits/splashes.
  """

  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.LineTargets
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
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
    - `:force_crit` - guarantee a critical, applying the crit multiplier without
      rolling (Auto Counter's counter strike); wins over `:skip_crit`
    - `:bonus_atk` - flat ATK added after the skill ratio, before defense
    - `:fixed_damage` - deal exactly this value, bypassing weapon/defense/flee
    - `:hit_count` - number of hits to deliver, each rolling its own hit/flee
      check and its own damage (default `1`)
    - `:display_hit_count` - packet-only divisions for one total-damage hit
    - `:hit_rate_bonus_pct` - relative percent bonus applied to the
      already-clamped hit rate for this attack's hit/flee roll only (e.g. a
      skill's own `+5%` per level accuracy bonus), not a flat addition to the
      `hit` stat (default `0`, see `HitCalculations.calculate_hit_rate/2`)
    - `:element` - forces the attack element for this hit, overriding the
      weapon element (e.g. Envenom's poison, Sand Attack's earth)
    - `:skip_range` - skip only the distance check (which gates on the caster's
      *weapon* attack range) for a cast whose skill range the interpreter
      already validated; map, life, and enemy-relation checks still run
      (default `false`)
    - `:report_hit` - when `true`, returns `{:ok, %{hit?: boolean}}` instead of
      plain `:ok`, so a caller can gate a follow-up effect (e.g. a status
      rider) on whether the attack actually connected rather than being
      dodged or missed. With `:hit_count` greater than `1`, `hit?` is `true`
      if any of the hits connected. Default `false`, so existing callers see
      no change. (default `false`)

  ## Returns
    - :ok if the skill was dispatched (regardless of whether any hit
      connected), when `:report_hit` is not set
    - {:ok, %{hit?: boolean}} when `:report_hit` is `true`
    - {:error, reason} if the target was invalid, friendly, dead, or out of range
  """
  @spec execute_skill_attack(struct(), integer(), keyword()) ::
          :ok | {:ok, %{hit?: boolean()}} | {:error, atom()}
  def execute_skill_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    hits = Keyword.get(opts, :hit_count, 1)
    report_hit? = Keyword.get(opts, :report_hit, false)
    display_hits = Keyword.get(opts, :display_hit_count, 1)
    hit_rate_bonus_pct = Keyword.get(opts, :hit_rate_bonus_pct, 0)

    calc_opts =
      Keyword.take(opts, [
        :skill_ratio,
        :skip_crit,
        :force_crit,
        :bonus_atk,
        :fixed_damage,
        :element,
        :skill_id
      ])

    validator_opts = Keyword.take(opts, [:skip_range]) ++ [projectile?: true]

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate(attacker, target, validator_opts),
         :ok <- Targeting.validate_enemy(attacker, target) do
      hit_opts = %{display_hits: display_hits, hit_rate_bonus_pct: hit_rate_bonus_pct}

      connected? =
        1..hits//1
        |> Enum.map(fn _ ->
          apply_skill_damage(
            attacker,
            target_type,
            target_pid,
            target,
            skill_id,
            skill_level,
            calc_opts,
            hit_opts
          )
        end)
        |> Enum.any?()

      if report_hit?, do: {:ok, %{hit?: connected?}}, else: :ok
    end
  end

  @doc """
  Executes a self/ground-centered splash skill against every offensive target in
  `radius` cells of `{x, y}`.

  Selects targets via `SplashTargets.select/4`, then runs each through the
  shared single-target damage path **without** the per-target attack-range
  gate — the radius already bounds the hit set. Each target rolls its own
  hit/flee check; a dodged or missed target is left out of the returned list.
  Returns the list of connected target ids, consumed by knockback.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll
    - `:hit_count` - number of hits each connected target takes, each rolling
      its own hit/flee check and its own damage (default `1`); a target
      counts as hit if any of its hits connect
  """
  @spec execute_splash_attack(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_splash_attack(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    {skill_id, skill_level, calc_opts} = multi_target_opts(opts)
    hits = Keyword.get(opts, :hit_count, 1)

    attacker.map_name
    |> SplashTargets.select(center, radius, attacker)
    |> hit_targets(attacker, skill_id, skill_level, calc_opts, hits)
  end

  @doc """
  Executes a line skill against the primary target plus every offensive
  target standing on the straight line of cells between the caster and it
  (inclusive of the target's own cell).

  Selects targets via `LineTargets.select/4`, then runs each through the
  shared single-target damage path **without** the per-target attack-range
  gate - the line already bounds the hit set. Each target rolls its own
  hit/flee check independently; there is no knockback. Returns the list of
  connected target ids.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll
  """
  @spec execute_line_attack(struct(), integer(), keyword()) :: [integer()]
  def execute_line_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    {skill_id, skill_level, calc_opts} = multi_target_opts(opts)

    case TargetResolver.resolve_target_position(target_id) do
      {:ok, _target_type, {tx, ty, _map_name}} ->
        {sx, sy} = attacker.position

        attacker.map_name
        |> LineTargets.select({sx, sy}, {tx, ty}, attacker)
        |> hit_targets(attacker, skill_id, skill_level, calc_opts, 1)

      {:error, _reason} ->
        []
    end
  end

  defp multi_target_opts(opts) do
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    calc_opts = Keyword.take(opts, [:skill_ratio, :skip_crit, :skill_id])

    {skill_id, skill_level, calc_opts}
  end

  defp hit_targets(targets, attacker, skill_id, skill_level, calc_opts, hits) do
    Enum.flat_map(targets, fn {_unit_type, target_id} ->
      apply_splash_hits(attacker, target_id, skill_id, skill_level, calc_opts, hits)
    end)
  end

  defp apply_splash_hits(attacker, target_id, skill_id, skill_level, calc_opts, hits) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         target <- target_state.__struct__.to_combatant(target_state) do
      connected? =
        1..hits//1
        |> Enum.map(fn _ ->
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
        |> Enum.any?()

      if connected?, do: [target_id], else: []
    else
      _ -> []
    end
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
      hit_info = %{
        dmg_type: :misc,
        is_short: false,
        element: element,
        skill_id: skill_id,
        skill_level: skill_level
      }

      {damage, hit_info} =
        DamageApplication.prepare_unit_damage(target_type, target_id, damage, hit_info)

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage
        )

      DamageApplication.broadcast_nearby(target, packet)

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

  # Rolls the weapon-class hit/flee check, then applies damage on a connect or
  # broadcasts the miss/perfect-dodge packet otherwise. Returns whether the
  # hit connected, so callers can gate follow-up effects (status riders) or
  # exclude a dodged target from a splash's knockback list.
  @spec apply_skill_damage(
          struct(),
          :player | :mob | :skill_unit,
          pid(),
          struct(),
          integer(),
          pos_integer(),
          keyword()
        ) :: boolean()
  defp apply_skill_damage(
         attacker,
         target_type,
         target_pid,
         target,
         skill_id,
         skill_level,
         calc_opts
       ),
       do:
         apply_skill_damage(
           attacker,
           target_type,
           target_pid,
           target,
           skill_id,
           skill_level,
           calc_opts,
           %{display_hits: nil, hit_rate_bonus_pct: 0}
         )

  defp apply_skill_damage(
         attacker,
         target_type,
         target_pid,
         target,
         skill_id,
         skill_level,
         calc_opts,
         hit_opts
       ) do
    %{display_hits: display_hits, hit_rate_bonus_pct: hit_rate_bonus_pct} = hit_opts

    case HitCalculations.calculate_hit_result(
           hit_stats(attacker, hit_rate_bonus_pct),
           flee_stats(target)
         ) do
      :miss ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_miss_packet(attacker, target)
        )

        false

      :perfect_dodge ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_perfect_dodge_packet(attacker, target)
        )

        false

      :hit ->
        deliver_skill_hit(
          attacker,
          target_type,
          target_pid,
          target,
          skill_id,
          skill_level,
          calc_opts,
          display_hits
        )
    end
  end

  defp deliver_skill_hit(
         attacker,
         target_type,
         target_pid,
         target,
         skill_id,
         skill_level,
         calc_opts,
         display_hits
       ) do
    case DamageCalculator.calculate_damage(attacker, target, calc_opts) do
      {:ok, damage_result} ->
        hit_info = %{
          dmg_type: :physical,
          is_short: attacker.attack_range <= 3,
          element: :neutral,
          skill_id: skill_id,
          skill_level: skill_level
        }

        {damage, hit_info} =
          DamageApplication.prepare_unit_damage(
            target_type,
            target.unit_id,
            damage_result.damage,
            hit_info
          )

        packet =
          skill_damage_packet(
            attacker,
            target,
            skill_id,
            skill_level,
            damage_result,
            damage,
            display_hits
          )

        DamageApplication.broadcast_nearby(target, packet)

        DamageApplication.apply_unit_damage(
          target_type,
          target_pid,
          target.unit_id,
          damage,
          hit_info,
          attacker.unit_id
        )

        OnHitEffects.after_hit(attacker, target, damage_result)

        true

      {:error, _reason} ->
        false
    end
  end

  defp hit_stats(attacker, hit_rate_bonus_pct) do
    %{
      hit: attacker.combat_stats.hit,
      char_id: attacker.unit_id,
      perfect_hit: EquipmentBonuses.perfect_hit_rate(attacker),
      hit_rate_bonus_pct: hit_rate_bonus_pct
    }
  end

  defp flee_stats(target) do
    %{
      flee: target.combat_stats.flee,
      perfect_dodge: target.combat_stats.perfect_dodge,
      unit_id: target.unit_id
    }
  end

  defp skill_damage_packet(attacker, target, skill_id, skill_level, damage_result, damage, nil) do
    PacketFactory.build_skill_damage_packet(
      attacker,
      target,
      skill_id,
      skill_level,
      %{damage_result | damage: damage}
    )
  end

  defp skill_damage_packet(
         attacker,
         target,
         skill_id,
         skill_level,
         damage_result,
         damage,
         display_hits
       ) do
    PacketFactory.build_skill_damage_packet(
      attacker,
      target,
      skill_id,
      skill_level,
      %{damage_result | damage: damage},
      div: display_hits
    )
  end
end
