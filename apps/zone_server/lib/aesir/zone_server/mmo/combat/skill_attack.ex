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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @max_uint32 0xFFFF_FFFF

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
    - `:report_hit` - when `true`, returns the hit result with `:hit?`, final
      prepared `:damage`, and `:target_survives?`. With `:hit_count` greater
      than `1`, damage is summed and `hit?` is `true` if any hit connected.
      Default `false`, so existing callers see no change. (default `false`)
    - `:ignore_flee` - when `true`, skips the hit/flee roll while retaining
      interception, validation, damage preparation, and delivery (default `false`)
    - `:ranged` - forces `is_short: false` in the delivered hit_info,
      overriding the caster's melee attack-range classification, for a skill
      whose reach is short but whose damage type is renewal's ranged physical
      class (e.g. a thrown spear) (default `false`)

  ## Returns
    - :ok if the skill was dispatched (regardless of whether any hit
      connected), when `:report_hit` is not set
    - `{:ok, %{hit?: boolean, damage: non_neg_integer,
      target_survives?: boolean}}` when `:report_hit` is `true`
    - {:error, reason} if the target was invalid, friendly, dead, or out of range
  """
  @spec execute_skill_attack(struct(), integer(), keyword()) ::
          :ok
          | {:ok, %{hit?: boolean(), damage: non_neg_integer(), target_survives?: boolean()}}
          | {:error, atom()}
  def execute_skill_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    hits = Keyword.get(opts, :hit_count, 1)
    report_hit? = Keyword.get(opts, :report_hit, false)
    display_hits = Keyword.get(opts, :display_hit_count, 1)
    hit_rate_bonus_pct = Keyword.get(opts, :hit_rate_bonus_pct, 0)
    ranged? = Keyword.get(opts, :ranged, false)

    calc_opts =
      Keyword.take(opts, [
        :skill_ratio,
        :skip_crit,
        :force_crit,
        :bonus_atk,
        :fixed_damage,
        :element,
        :skill_id
      ]) ++ shield_base_opts(caster_state, opts)

    validator_opts = Keyword.take(opts, [:skip_range]) ++ [projectile?: true]

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate(attacker, target, validator_opts),
         :ok <- Targeting.validate_enemy(attacker, target) do
      hit_opts = %{
        display_hits: display_hits,
        hit_rate_bonus_pct: hit_rate_bonus_pct,
        ignore_flee: Keyword.get(opts, :ignore_flee, false),
        ranged: ranged?
      }

      results =
        Enum.map(1..hits//1, fn _ ->
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

      if report_hit?, do: {:ok, reported_hit(results, target_state)}, else: :ok
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
    - `:ranged` - forces `is_short: false` in each connected target's hit_info
      (default `false`, see `execute_skill_attack/3`)
  """
  @spec execute_splash_attack(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_splash_attack(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    {skill_id, skill_level, calc_opts} = multi_target_opts(opts)
    hits = Keyword.get(opts, :hit_count, 1)
    ranged? = Keyword.get(opts, :ranged, false)
    ignore_flee? = Keyword.get(opts, :ignore_flee, false)

    attacker.map_name
    |> SplashTargets.select(center, radius, attacker)
    |> hit_targets(attacker, skill_id, skill_level, calc_opts, hits, ranged?, ignore_flee?)
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

  # Resolves the shield damage base for a `damage_base: :shield` skill: the worn
  # shield contributes `4×refine + weight/10` on top of the caster's stat batk,
  # replacing the weapon ATK. Player-only — a mob caster carries no shield and
  # falls through to its plain weapon/batk base. A player with no shield equipped
  # (guarded against by the skill's cast validation) likewise falls through.
  defp shield_base_opts(%{inventory: inventory, stats: stats}, opts) do
    if Keyword.get(opts, :damage_base) == :shield do
      inventory = Map.values(inventory)

      case PlayerStats.shield_stats(stats.equipment, inventory) do
        {weight, refine} -> [shield_base: 4 * refine + div(weight, 10)]
        nil -> []
      end
    else
      []
    end
  end

  defp shield_base_opts(_caster_state, _opts), do: []

  defp multi_target_opts(opts) do
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    calc_opts = Keyword.take(opts, [:skill_ratio, :skip_crit, :skill_id])

    {skill_id, skill_level, calc_opts}
  end

  defp hit_targets(
         targets,
         attacker,
         skill_id,
         skill_level,
         calc_opts,
         hits,
         ranged? \\ false,
         ignore_flee? \\ false
       ) do
    Enum.flat_map(targets, fn {_unit_type, target_id} ->
      apply_splash_hits(
        attacker,
        target_id,
        skill_id,
        skill_level,
        calc_opts,
        hits,
        ranged?,
        ignore_flee?
      )
    end)
  end

  defp apply_splash_hits(
         attacker,
         target_id,
         skill_id,
         skill_level,
         calc_opts,
         hits,
         ranged?,
         ignore_flee?
       ) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         target <- target_state.__struct__.to_combatant(target_state) do
      hit_opts = %{
        display_hits: nil,
        hit_rate_bonus_pct: 0,
        ignore_flee: ignore_flee?,
        ranged: ranged?
      }

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
        |> Enum.any?(& &1.hit?)

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

    apply_misc_hit(attacker, target_id, skill_id, skill_level, element, base_damage, 1)
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
    - `:display_hit_count` - packet-only divisions for the total damage (default `1`)
    - `:split` - divide one supplied base by the selected living-enemy count
      before target-specific damage processing (default `false`)
  """
  @spec execute_misc_splash(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_misc_splash(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)
    display_hits = display_hit_count!(opts)

    targets = SplashTargets.select(attacker.map_name, center, radius, attacker)
    base_damage = split_base_damage(base_damage, targets, Keyword.get(opts, :split, false))

    Enum.flat_map(targets, fn {_unit_type, target_id} ->
      case apply_misc_hit(
             attacker,
             target_id,
             skill_id,
             skill_level,
             element,
             base_damage,
             display_hits
           ) do
        :ok -> [target_id]
        _ -> []
      end
    end)
  end

  defp split_base_damage(base_damage, [], true), do: base_damage
  defp split_base_damage(base_damage, targets, true), do: div(base_damage, length(targets))
  defp split_base_damage(base_damage, _targets, false), do: base_damage

  defp display_hit_count!(opts) do
    case Keyword.get(opts, :display_hit_count, 1) do
      count when is_integer(count) and count > 0 and count <= @max_uint32 -> count
      invalid -> raise ArgumentError, "invalid display hit count: #{inspect(invalid)}"
    end
  end

  defp apply_misc_hit(
         attacker,
         target_id,
         skill_id,
         skill_level,
         element,
         base_damage,
         display_hits
       ) do
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
        DamageApplication.prepare_unit_damage(
          target_type,
          target_id,
          damage,
          hit_info,
          attacker.unit_id
        )

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage,
          div: display_hits
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
          keyword(),
          map()
        ) :: %{hit?: boolean(), damage: non_neg_integer()}
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
    if weapon_hit_intercepted?(attacker, target_type, target) do
      %{hit?: false, damage: 0}
    else
      resolve_skill_hit(
        attacker,
        target_type,
        target_pid,
        target,
        skill_id,
        skill_level,
        calc_opts,
        hit_opts
      )
    end
  end

  # A weapon-class skill hit passes through the target's `before_weapon_hit`
  # interception statuses (Guard) exactly as a basic attack does, but tagged
  # `basic_attack?: false` so basic-attack-only stances (Auto Counter, Blade
  # Stop) stay inert. An interception cancels this hit entirely: no hit roll, no
  # damage, no packet - the intercepting status owns its own feedback effect.
  # Magic and misc skills never call this path, so they can never be blocked.
  @spec weapon_hit_intercepted?(struct(), :player | :mob | :skill_unit, struct()) :: boolean()
  defp weapon_hit_intercepted?(attacker, target_type, target) do
    attack_info = %{
      attacker: {attacker.unit_type, attacker.unit_id},
      target: {target_type, target.unit_id},
      attacker_boss?: attacker.class == :boss,
      attacker_root_level: 0,
      attacker_position: attacker.position,
      attacker_short?: attacker.attack_range <= 3,
      distance: cell_distance(attacker, target),
      basic_attack?: false
    }

    match?(
      {:intercept, _result},
      StatusInterpreter.before_weapon_hit(target_type, target.unit_id, attack_info)
    )
  end

  @spec cell_distance(struct(), struct()) :: non_neg_integer()
  defp cell_distance(%{position: {ax, ay}}, %{position: {tx, ty}}),
    do: max(abs(ax - tx), abs(ay - ty))

  defp cell_distance(_attacker, _target), do: 0

  defp resolve_skill_hit(
         attacker,
         target_type,
         target_pid,
         target,
         skill_id,
         skill_level,
         calc_opts,
         hit_opts
       ) do
    %{hit_rate_bonus_pct: hit_rate_bonus_pct, ignore_flee: ignore_flee?} = hit_opts

    hit_result =
      if ignore_flee? do
        :hit
      else
        HitCalculations.calculate_hit_result(
          hit_stats(attacker, hit_rate_bonus_pct),
          flee_stats(target)
        )
      end

    case hit_result do
      :miss ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_miss_packet(attacker, target)
        )

        %{hit?: false, damage: 0}

      :perfect_dodge ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_perfect_dodge_packet(attacker, target)
        )

        %{hit?: false, damage: 0}

      :hit ->
        deliver_skill_hit(
          attacker,
          target_type,
          target_pid,
          target,
          skill_id,
          skill_level,
          calc_opts,
          hit_opts
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
         hit_opts
       ) do
    %{display_hits: display_hits, ranged: ranged?} = hit_opts

    case DamageCalculator.calculate_damage(attacker, target, calc_opts) do
      {:ok, damage_result} ->
        hit_info = %{
          dmg_type: :physical,
          is_short: not ranged? and attacker.attack_range <= 3,
          element: :neutral,
          skill_id: skill_id,
          skill_level: skill_level
        }

        {damage, hit_info} =
          DamageApplication.prepare_unit_damage(
            target_type,
            target.unit_id,
            damage_result.damage,
            hit_info,
            attacker.unit_id
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

        %{hit?: true, damage: damage}

      {:error, _reason} ->
        %{hit?: false, damage: 0}
    end
  end

  defp reported_hit(results, target_state) do
    damage = Enum.sum_by(results, & &1.damage)

    %{
      hit?: Enum.any?(results, & &1.hit?),
      damage: damage,
      target_survives?: target_hp(target_state) > damage
    }
  end

  defp target_hp(%{stats: %{current_state: %{hp: hp}}}), do: hp
  defp target_hp(%{hp: hp}), do: hp

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
