defmodule Aesir.ZoneServer.Mmo.Combat.SkillAttack do
  defmodule PreparedHit do
    @moduledoc """
    Opaque connected physical hit awaiting authoritative settlement.

    Constructed only by `SkillAttack.prepare_staged_skill_attack/3` and consumed
    only by `SkillAttack.deliver_prepared_skill_hit/1`.
    """

    @enforce_keys [
      :attacker,
      :target_type,
      :target_pid,
      :target,
      :skill_id,
      :skill_level,
      :damage_result,
      :display_hits,
      :ranged
    ]
    defstruct @enforce_keys

    @opaque t :: %__MODULE__{}
  end

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
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell, as: SkillUnitCell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombatTarget
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Ref

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
    - `:base_damage` - non-negative integer replacing only the unit-specific
      base attack roll; the normal ratio/modifier/defense pipeline still applies
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
  @spec execute_skill_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok, %{hit?: boolean(), damage: non_neg_integer(), target_survives?: boolean()}}
          | {:error, atom()}
  def execute_skill_attack(caster_state, target_id, opts) do
    execute_single_target_attack(
      caster_state,
      target_id,
      opts,
      &DamageCalculator.calculate_damage/3
    )
  end

  @doc """
  Prepares one connected physical skill hit without delivering it.

  This dedicated seam performs target validation, one hit/flee decision, and the
  ordinary raw physical damage calculation. Miss feedback is broadcast
  immediately. A connected hit is returned as an opaque descriptor; no
  pre-delivery status hook, damage packet, target damage, or on-hit effect runs
  until `deliver_prepared_skill_hit/1` is called.
  """
  @spec prepare_staged_skill_attack(struct(), integer() | Ref.t(), keyword()) ::
          {:ok, :miss | PreparedHit.t()} | {:error, atom()}
  def prepare_staged_skill_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    display_hits = Keyword.get(opts, :display_hit_count, 1)
    hit_rate_bonus_pct = Keyword.get(opts, :hit_rate_bonus_pct, 0)

    calc_opts = physical_skill_calc_opts(caster_state, opts)
    validator_opts = physical_skill_validator_opts(opts)

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate(attacker, target, validator_opts),
         :ok <- Targeting.validate_enemy(attacker, target) do
      if weapon_hit_intercepted?(attacker, target_type, target) do
        {:ok, :miss}
      else
        prepare_staged_skill_hit(
          {attacker, target_type, target_pid, target},
          skill_id,
          skill_level,
          calc_opts,
          %{
            display_hits: display_hits,
            hit_rate_bonus_pct: hit_rate_bonus_pct,
            ignore_flee: Keyword.get(opts, :ignore_flee, false),
            ranged: Keyword.get(opts, :ranged, false)
          }
        )
      end
    end
  end

  @doc "Delivers one opaque hit returned by `prepare_staged_skill_attack/3`."
  @spec deliver_prepared_skill_hit(PreparedHit.t()) :: :ok
  def deliver_prepared_skill_hit(%PreparedHit{} = prepared) do
    %PreparedHit{
      attacker: attacker,
      target_type: target_type,
      target_pid: target_pid,
      target: target,
      skill_id: skill_id,
      skill_level: skill_level,
      damage_result: damage_result,
      display_hits: display_hits,
      ranged: ranged?
    } = prepared

    _damage =
      deliver_calculated_skill_hit(
        attacker,
        {target_type, target_pid, target},
        skill_id,
        skill_level,
        damage_result,
        display_hits,
        ranged?
      )

    :ok
  end

  @doc """
  Executes Acid Terror through the weapon-damage path while ignoring status DEF.

  All ordinary skill-attack validation, hit delivery, and on-hit handling remain
  active. Only the damage calculator's status-DEF term is omitted.
  """
  @spec execute_acid_terror_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok, %{hit?: boolean(), damage: non_neg_integer(), target_survives?: boolean()}}
          | {:error, atom()}
  def execute_acid_terror_attack(caster_state, target_id, opts) do
    execute_single_target_attack(
      caster_state,
      target_id,
      opts,
      &DamageCalculator.calculate_damage_ignoring_status_def/3
    )
  end

  defp execute_single_target_attack(caster_state, target_id, opts, damage_calculator) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    hits = Keyword.get(opts, :hit_count, 1)
    report_hit? = Keyword.get(opts, :report_hit, false)
    display_hits = Keyword.get(opts, :display_hit_count, 1)
    hit_rate_bonus_pct = Keyword.get(opts, :hit_rate_bonus_pct, 0)
    ranged? = Keyword.get(opts, :ranged, false)

    calc_opts = physical_skill_calc_opts(caster_state, opts)
    validator_opts = physical_skill_validator_opts(opts)

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
            {calc_opts, damage_calculator},
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
    - `:element` - optional attack-element override
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
  @spec execute_line_attack(struct(), integer() | Ref.t(), keyword()) :: [integer()]
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

  defp physical_skill_calc_opts(caster_state, opts) do
    Keyword.take(opts, [
      :skill_ratio,
      :skip_crit,
      :force_crit,
      :bonus_atk,
      :base_damage,
      :fixed_damage,
      :element,
      :skill_id
    ]) ++ shield_base_opts(caster_state, opts)
  end

  defp physical_skill_validator_opts(opts),
    do: Keyword.take(opts, [:skip_range]) ++ [projectile?: true]

  defp multi_target_opts(opts) do
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    calc_opts = Keyword.take(opts, [:skill_ratio, :skip_crit, :skill_id, :element])

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
    Enum.flat_map(targets, fn {_unit_type, _target_id} = target_ref ->
      apply_splash_hits(
        attacker,
        target_ref,
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
         target_ref,
         skill_id,
         skill_level,
         calc_opts,
         hits,
         ranged?,
         ignore_flee?
       ) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
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

      if connected?, do: [elem(target_ref, 1)], else: []
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
    - `:ignore_element` - bypass the element table (default `false`)
  """
  @spec execute_misc_attack(struct(), integer() | Ref.t(), keyword()) :: :ok | {:error, atom()}
  def execute_misc_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)

    apply_misc_hit(
      attacker,
      target_id,
      skill_id,
      skill_level,
      element,
      base_damage,
      1,
      %{
        ignore_element?: Keyword.get(opts, :ignore_element, false),
        owner_derived_trap?: false
      }
    )
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
    - `:ignore_element` - bypass the element table (default `false`)
    - `:target_skill_units` - include only live targetable traps (default `false`)
    - `:shoot_range_los` - require projectile line of sight from the splash center
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

    target_skill_units? = Keyword.get(opts, :target_skill_units, false)

    targets =
      SplashTargets.select(attacker.map_name, center, radius, attacker, false,
        target_skill_units: target_skill_units?,
        shoot_range_los: Keyword.get(opts, :shoot_range_los, false)
      )

    base_damage = split_base_damage(base_damage, targets, Keyword.get(opts, :split, false))
    ignore_element? = Keyword.get(opts, :ignore_element, false)

    Enum.flat_map(targets, fn {_unit_type, target_id} = target_ref ->
      case apply_misc_hit(
             attacker,
             target_ref,
             skill_id,
             skill_level,
             element,
             base_damage,
             display_hits,
             %{
               ignore_element?: ignore_element?,
               owner_derived_trap?: target_skill_units?
             }
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
         target_ref,
         skill_id,
         skill_level,
         element,
         base_damage,
         display_hits,
         misc_opts
       ) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         {:ok, target} <-
           misc_target_combatant(target_state, misc_opts.owner_derived_trap?),
         target_id <- target.unit_id,
         :ok <- Targeting.validate_enemy(attacker, target),
         {:ok, %{damage: damage}} <-
           MiscDamageCalculator.calculate_misc_damage(
             attacker,
             target,
             misc_damage_opts(base_damage, element, misc_opts.ignore_element?)
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
          damage_source(attacker, target_type)
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
        damage_source(attacker, target_type)
      )
    end
  end

  defp prepare_staged_skill_hit(
         {attacker, target_type, target_pid, target},
         skill_id,
         skill_level,
         calc_opts,
         hit_opts
       ) do
    %{
      display_hits: display_hits,
      hit_rate_bonus_pct: hit_rate_bonus_pct,
      ignore_flee: ignore_flee?,
      ranged: ranged?
    } = hit_opts

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

        {:ok, :miss}

      :perfect_dodge ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_perfect_dodge_packet(attacker, target)
        )

        {:ok, :miss}

      :hit ->
        case DamageCalculator.calculate_damage(attacker, target, calc_opts) do
          {:ok, damage_result} ->
            {:ok,
             %PreparedHit{
               attacker: attacker,
               target_type: target_type,
               target_pid: target_pid,
               target: target,
               skill_id: skill_id,
               skill_level: skill_level,
               damage_result: damage_result,
               display_hits: display_hits,
               ranged: ranged?
             }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp misc_target_combatant(%SkillUnitCell{} = cell, true),
    do: TrapCombatTarget.to_combatant(cell)

  defp misc_target_combatant(%SkillUnitCell{} = cell, false),
    do: {:ok, CombatTarget.to_combatant(cell)}

  defp misc_target_combatant(target_state, _owner_derived_trap?),
    do: {:ok, target_state.__struct__.to_combatant(target_state)}

  defp misc_damage_opts(base_damage, element, false),
    do: [base_damage: base_damage, element: element]

  defp misc_damage_opts(base_damage, element, true),
    do: [base_damage: base_damage, element: element, ignore_element: true]

  # Rolls the weapon-class hit/flee check, then applies damage on a connect or
  # broadcasts the miss/perfect-dodge packet otherwise. Returns whether the
  # hit connected, so callers can gate follow-up effects (status riders) or
  # exclude a dodged target from a splash's knockback list.
  @spec apply_skill_damage(
          struct(),
          :player | :mob | :homunculus | :skill_unit,
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
         calc_context,
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
        calc_context,
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
  @spec weapon_hit_intercepted?(
          struct(),
          :player | :mob | :homunculus | :skill_unit,
          struct()
        ) :: boolean()
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
         calc_context,
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
          calc_context,
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
         calc_context,
         hit_opts
       ) do
    %{display_hits: display_hits, ranged: ranged?} = hit_opts
    {calc_opts, damage_calculator} = damage_calculation(calc_context)

    case damage_calculator.(attacker, target, calc_opts) do
      {:ok, damage_result} ->
        damage =
          deliver_calculated_skill_hit(
            attacker,
            {target_type, target_pid, target},
            skill_id,
            skill_level,
            damage_result,
            display_hits,
            ranged?
          )

        %{hit?: true, damage: damage}

      {:error, _reason} ->
        %{hit?: false, damage: 0}
    end
  end

  defp damage_source(%{unit_type: unit_type, unit_id: unit_id}, target_type)
       when unit_type == :homunculus or target_type == :homunculus,
       do: {unit_type, unit_id}

  defp damage_source(%{unit_id: unit_id}, _target_type), do: unit_id

  defp deliver_calculated_skill_hit(
         attacker,
         {target_type, target_pid, target},
         skill_id,
         skill_level,
         damage_result,
         display_hits,
         ranged?
       ) do
    hit_info = %{
      dmg_type: :physical,
      is_short: not ranged? and attacker.attack_range <= 3,
      element: :neutral,
      skill_id: skill_id,
      skill_level: skill_level
    }

    source = damage_source(attacker, target_type)

    {damage, hit_info} =
      DamageApplication.prepare_unit_damage(
        target_type,
        target.unit_id,
        damage_result.damage,
        hit_info,
        source
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
      source
    )

    OnHitEffects.after_hit(attacker, target, damage_result)
    damage
  end

  defp damage_calculation({calc_opts, damage_calculator}),
    do: {calc_opts, damage_calculator}

  defp damage_calculation(calc_opts),
    do: {calc_opts, &DamageCalculator.calculate_damage/3}

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
      hit_rate_bonus_pct:
        hit_rate_bonus_pct + Map.get(attacker.combat_stats, :hit_rate_bonus_pct, 0)
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
