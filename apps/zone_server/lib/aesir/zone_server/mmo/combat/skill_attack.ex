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
      :target,
      :skill_id,
      :skill_level,
      :damage_result,
      :divisions,
      :element,
      :long?,
      :coma?,
      :knockback_options
    ]
    defstruct @enforce_keys

    @opaque t :: %__MODULE__{}
  end

  @moduledoc """
  Physical (BF_WEAPON) and misc (BF_MISC) offensive skill paths: single-target
  skill strikes, ground-centered physical splashes, line strikes, and trap
  hits/splashes.
  """

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Critical
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Combat.EquipVanish
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.LineTargets
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SkillRange
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell, as: SkillUnitCell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombatTarget
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Ref

  @palm_strike_id 370
  @sacrifice 368

  @typep damage_calculator ::
           (struct(), struct(), keyword() -> {:ok, map()} | {:error, atom()})

  # The damage-calculation context threaded down to `apply_skill_damage/7`:
  # either bare calculator options (implying `DamageCalculator.calculate_damage/3`)
  # or an explicit `{opts, calculator}` pair for skills using another formula.
  @typep calc_context :: keyword() | {keyword(), damage_calculator()}

  # One resolved attack against one target: whether it connected, its settled
  # total before Devotion forwarding, what the target itself took, the
  # client-visible division count, and its `DamageShared.hit_class/3`.
  @typep resolved_hit :: %{
           hit?: boolean(),
           damage: non_neg_integer(),
           taken: non_neg_integer(),
           divisions: non_neg_integer(),
           class: :miss | :block | :hit
         }

  @typedoc """
  A resolved skill hit as its caller sees it.

    * `hit?` - the hit's additional effects apply: it connected for a total of
      at least 1 and is neither blocked nor a delayed Devotion-forwarded hit.
    * `blocked?` - a blocking status stopped it, or Devotion forwarded it after
      the attack motion.
    * `connected?` - it reached delivery (no miss, flee or interception).
    * `damage` - the settled total before Devotion forwarding.
    * `target_survives?`, `coma?` - the target's logical survival and coma.
  """
  @type hit_report() :: %{
          hit?: boolean(),
          blocked?: boolean(),
          connected?: boolean(),
          damage: non_neg_integer(),
          target_survives?: boolean(),
          coma?: boolean()
        }

  @doc """
  Executes a single-target offensive skill from a caster against a target.

  Reuses the melee range check and the unified damage calculator (passing the
  skill's ratio), broadcasts a ZC_NOTIFY_SKILL packet, then applies damage.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll (most skills don't crit)
    - `:critical` - opt into a critical roll before flee; a critical bypasses
      flee and forces the calculator, a failed roll prevents a second roll.
      Wins over `:skip_crit` / `:force_crit`; callers should not mix them.
    - `:critical_rate_bonus` - flat critical percentage points (default `0`)
    - `:critical_max_weapon` - retain maximum weapon damage on criticals
      (default `true`); `false` keeps normal weapon variance
    - `:force_crit` - guarantee a critical, applying the crit multiplier without
      rolling (Auto Counter's counter strike); wins over `:skip_crit`
    - `:bonus_atk` - flat ATK added after the skill ratio, before defense
    - `:base_atk_rate` - percent of the Renewal non-mastery attack core (default `100`)
    - `:weight_atk` - flat weapon equipment ATK from item weight (default `0`)
    - `:ignore_size` - bypass weapon-size penalty for this hit (default `false`)
    - `:base_damage` - non-negative integer replacing only the unit-specific
      base attack roll; the normal ratio/modifier/defense pipeline still applies
    - `:fixed_damage` - deal exactly this value, bypassing weapon/defense/flee
    - `:hit_divisions` - the attack's signed hit divisions (default `1`): one
      hit/flee roll and one damage calculation, whose result is repeated for a
      positive count or floored to an equal split for a negative one
      (`DamageShared.normalize_damage_divisions/2`); the normalized count is
      the packet division. The caller resolves the source's runtime overrides
      (target size, weapon, spheres) before passing it.
    - `:hit_rate_bonus_pct` - relative percent bonus applied to the
      already-clamped hit rate for this attack's hit/flee roll only (e.g. a
      skill's own `+5%` per level accuracy bonus), not a flat addition to the
      `hit` stat (default `0`, see `HitCalculations.calculate_hit_rate/2`)
    - `:hit_rate_bonus_flat` - flat percentage points added to the hit rate
      after the clamp and the relative bonuses (Rapid Smiting's +20)
      (default `0`)
    - `:element` - forces the attack element for this hit, overriding the
      weapon element (e.g. Envenom's poison, Sand Attack's earth)
    - `:dmg_type` - the damage kind the delivered hit carries to every flag
      consumer (absorbing and blocking statuses, procs, on-hit and vanish
      effects, reflection, kill classification): `:physical` (default) or
      `:misc` for a hit calculated as a weapon attack but flagged as misc (a
      monster's Spiral Pierce). The calculation itself is unchanged.
    - `:skip_range` - skip only the distance check (which gates on the caster's
      *weapon* attack range) for a cast whose skill range the interpreter
      already validated; map, life, and enemy-relation checks still run
      (default `false`)
    - `:report_hit` - when `true`, returns the `t:hit_report/0` (default `false`)
    - `:ignore_flee` - when `true`, skips the hit/flee roll while retaining
      interception, validation, damage preparation, and delivery, so the strike
      always connects (e.g. Occult Impaction, Asura Strike) (default `false`)
    - `:fled` - when `true`, the caller already rolled this attack's hit and the
      target fled it (an attack replacement): the roll is skipped, the damage a
      fled attack still deals lands as a hit, and a fled attack that deals
      nothing reports `hit?: false` without miss feedback, which the caller owns
      (default `false`)
    - `:simple_defense` - when `true`, the target's DEF is dropped as a flat
      hard+soft subtraction instead of the renewal DEF curve (e.g. Asura
      Strike) (default `false`)
    - `:ignore_defense` - when `true`, the target's DEF is skipped entirely
      (classic Asura Strike) (default `false`)
    - `:skip_status_atk` - when `true`, the attacker's flat status ATK bonuses
      are not applied to this hit; the ATK percent and the generic damage
      multiplier still are.
      Only honoured by the ordinary pipeline, i.e. together with `:base_damage`
      (Sacrifice, whose base is a share of max HP) (default `false`)
    - `:base_distance` - native knockback cells (default `0`)
    - `:origin` - native/equipment knockback origin; `nil` uses the attacker's
      position (default `nil`)
    - `:native_enabled` - whether native distance participates (default `true`)
    - `:native_target_types` - target types eligible for native distance
      (default all target types)
    - `:native_requires_survival` - require the logical target to survive before
      native distance participates (default `false`)

      Native restrictions gate only `:base_distance`; equipment distance for the
      named landed skill participates independently.
    - `:equipment_blow` - `false` drops the equipment knockback distance too,
      for a hit that carries no knockback at all (default `true`)
    - `:delivery` - how the hit reached the target (`t:Targeting.delivery/0`,
      default `:direct`); a recipient refused by
      `Targeting.validate_delivery/4` is neither calculated nor struck

  A hit the caster's own Gravitation Field suppresses
  (`StatusInterpreter.can_deal_skill_damage?/4`) is not calculated either: it
  reports `hit?: false` with no packet, rider, knockback or proc, and the
  caller's costs stay spent.

  ## Returns
    - :ok if the skill was dispatched (regardless of whether any hit
      connected), when `:report_hit` is not set
    - `{:ok, hit_report()}` when `:report_hit` is `true`
    - {:error, reason} if the target was invalid, friendly, dead, or out of range
  """
  @spec execute_skill_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok, hit_report()}
          | {:error, atom()}
  def execute_skill_attack(caster_state, target_id, opts) do
    execute_single_target_attack(caster_state, target_id, opts, calculator(opts), %{})
  end

  defp calculator(opts) do
    cond do
      Keyword.get(opts, :ignore_defense, false) ->
        &DamageCalculator.calculate_damage_ignoring_defense/3

      Keyword.get(opts, :simple_defense, false) ->
        &DamageCalculator.calculate_damage_simple_defense/3

      true ->
        &DamageCalculator.calculate_damage/3
    end
  end

  @doc """
  Executes a physical hit owned by a supported player field.

  This restricted entry preserves the ordinary validation, calculation, hooks,
  and settlement path while replacing only enemy authorization with the exact
  source group's field authorization. The supplied skill id and level must
  match the authoritative group. The field is the hit's actual source, so
  `:delivery` defaults to `:unit`.
  """
  @spec execute_field_skill_attack(struct(), Ref.t(), Group.t(), keyword()) ::
          :ok
          | {:ok, hit_report()}
          | {:error, atom()}
  def execute_field_skill_attack(caster_state, target_ref, %Group{} = group, opts) do
    calculator = calculator(opts)

    with :ok <- validate_field_skill_opts(group, opts) do
      execute_single_target_attack(
        caster_state,
        target_ref,
        Keyword.put_new(opts, :delivery, :unit),
        calculator,
        %{},
        &Targeting.validate_field_target(group, &1, &2)
      )
    end
  end

  @doc """
  Executes Sonic Blow through the ordinary primary-hand weapon path.

  When `:accelerated` is true, the player's HIT and the fully calculated damage
  gain the `:acceleration` rates (`%{hit_rate: 90, damage_rate: 190}` by
  default, the renewal Sonic Acceleration bonus) immediately before delivery.
  Mob casters are never accelerated.
  """
  @spec execute_sonic_blow_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok, hit_report()}
          | {:error, atom()}
  def execute_sonic_blow_attack(caster_state, target_id, opts) do
    accelerated? = Keyword.get(opts, :accelerated, false) and match?(%PlayerState{}, caster_state)
    rates = Keyword.get(opts, :acceleration, %{hit_rate: 90, damage_rate: 190})
    caster_state = maybe_accelerate_hit(caster_state, accelerated?, rates.hit_rate)
    opts = Keyword.drop(opts, [:accelerated, :acceleration])

    calculator =
      if accelerated?,
        do: &calculate_accelerated_damage(&1, &2, &3, rates.damage_rate),
        else: &DamageCalculator.calculate_damage/3

    execute_single_target_attack(caster_state, target_id, opts, calculator, %{})
  end

  @doc """
  Executes Stave Crasher through the ordinary single-target weapon path.

  The caster's MATK band is rolled once, half-open, before validation, and that
  roll reaches `DamageCalculator.calculate_stave_crasher_damage/3`. Every other
  option, gate and delivery step is `execute_skill_attack/3`'s.
  """
  @spec execute_stave_crasher_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok, hit_report()}
          | {:error, atom()}
  def execute_stave_crasher_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    matk = DamageInputs.roll_matk(attacker.combat_stats)

    calculator = fn attacker, defender, calc_opts ->
      DamageCalculator.calculate_stave_crasher_damage(
        attacker,
        defender,
        Keyword.put(calc_opts, :matk, matk)
      )
    end

    execute_single_target_attack(caster_state, target_id, opts, calculator, %{})
  end

  defp calculate_accelerated_damage(attacker, defender, calc_opts, damage_rate) do
    with {:ok, result} <- DamageCalculator.calculate_damage(attacker, defender, calc_opts) do
      {:ok, %{result | damage: div(result.damage * damage_rate, 100)}}
    end
  end

  defp maybe_accelerate_hit(%PlayerState{stats: stats} = caster, true, hit_rate) do
    hit = stats.combat_stats.hit
    combat_stats = %{stats.combat_stats | hit: hit + div(hit * hit_rate, 100)}
    %{caster | stats: %{stats | combat_stats: combat_stats}}
  end

  defp maybe_accelerate_hit(caster, _accelerated?, _hit_rate), do: caster

  @doc """
  Executes the forced-hit, no-attacker-card physical path used by Venom Knife.

  This narrow entry forces neutral damage and marks only Auto Guard
  as exempt. Every other weapon interception and ordinary damage-delivery hook
  remains active.
  """
  @spec execute_forced_no_card_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok, hit_report()}
          | {:error, atom()}
  def execute_forced_no_card_attack(caster_state, target_id, opts) do
    opts = Keyword.merge(opts, ignore_flee: true, element: :neutral)

    execute_single_target_attack(
      caster_state,
      target_id,
      opts,
      &DamageCalculator.calculate_damage_ignoring_attacker_cards/3,
      %{ignores_auto_guard: true}
    )
  end

  @doc """
  Prepares one connected physical skill hit without delivering it.

  This dedicated seam performs target validation, one hit/flee decision, and the
  ordinary raw physical damage calculation. Miss feedback is broadcast
  immediately. A connected hit is returned as an opaque descriptor; no
  pre-delivery status hook, damage packet, target damage, or on-hit effect runs
  until `deliver_prepared_skill_hit/1` is called. Combined knockback options from
  `execute_skill_attack/3` are retained until that delivery completes.

  A hit the caster's own Gravitation Field suppresses returns `{:ok, :suppressed}`
  before any roll; `deliver_prepared_skill_hit/1` accepts it and does nothing.
  """
  @spec prepare_staged_skill_attack(struct(), integer() | Ref.t(), keyword()) ::
          {:ok, :miss | :suppressed | PreparedHit.t()} | {:error, atom()}
  def prepare_staged_skill_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    hit_rate_bonus_pct = Keyword.get(opts, :hit_rate_bonus_pct, 0)

    calc_opts = physical_skill_calc_opts(caster_state, opts)
    validator_opts = physical_skill_validator_opts(opts)

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate(attacker, target, validator_opts),
         :ok <- Targeting.validate_enemy(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}),
         :ok <- StatusInterpreter.authorize_skill_damage(attacker, skill_id) do
      interception = weapon_hit_intercepted?(attacker, target_type, target, %{})

      if interception == :blocked,
        do: missed_coma(attacker, {target_type, target_pid, target})

      if interception != :continue do
        {:ok, :miss}
      else
        prepare_staged_skill_hit(
          {attacker, target_type, target},
          skill_id,
          skill_level,
          calc_opts,
          %{
            hit_divisions: Keyword.get(opts, :hit_divisions, 1),
            hit_rate_bonus_pct: hit_rate_bonus_pct,
            hit_rate_bonus_flat: Keyword.get(opts, :hit_rate_bonus_flat, 0),
            ignore_flee: Keyword.get(opts, :ignore_flee, false),
            knockback_options: knockback_options(opts)
          }
        )
      end
    else
      :suppressed -> {:ok, :suppressed}
      error -> error
    end
  end

  @doc """
  Delivers one opaque hit returned by `prepare_staged_skill_attack/3`.

  The hit was calculated when it was prepared, so it is not gated again: a
  caster whose Gravitation Field started since still lands it. A `:suppressed`
  preparation delivers nothing.
  """
  @spec deliver_prepared_skill_hit(PreparedHit.t() | :suppressed) :: :ok
  def deliver_prepared_skill_hit(:suppressed), do: :ok

  def deliver_prepared_skill_hit(%PreparedHit{} = prepared) do
    %PreparedHit{
      attacker: prepared_attacker,
      target_type: target_type,
      target: prepared_target,
      skill_id: skill_id,
      skill_level: skill_level,
      damage_result: damage_result,
      divisions: divisions,
      element: element,
      long?: long?,
      coma?: coma?,
      knockback_options: knockback_options
    } = prepared

    with {:ok, target_pid, target_state, ^target_type} <-
           TargetResolver.resolve({target_type, prepared_target.unit_id}),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         {:ok, _attacker_pid, attacker_state, attacker_type} <-
           TargetResolver.resolve({prepared_attacker.unit_type, prepared_attacker.unit_id}),
         ^attacker_type <- prepared_attacker.unit_type,
         attacker <- attacker_state.__struct__.to_combatant(attacker_state),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}) do
      hit =
        deliver_calculated_skill_hit(
          attacker,
          {target_type, target_pid, target},
          skill_id,
          skill_level,
          damage_result,
          %{
            divisions: divisions,
            element: element,
            long?: long?,
            coma?: coma?,
            target_state: target_state,
            delivery: :direct
          }
        )

      result = logical_skill_result(hit, target_state, coma?)
      maybe_apply_skill_knockback(attacker, target, skill_id, hit, result, knockback_options)
    end

    :ok
  end

  @doc """
  Executes Acid Terror through the weapon-damage path while ignoring status DEF.

  All ordinary skill-attack validation, hit delivery, and on-hit handling remain
  active. Only the damage calculator's status-DEF term is omitted.
  """
  @spec execute_acid_terror_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok, hit_report()}
          | {:error, atom()}
  def execute_acid_terror_attack(caster_state, target_id, opts) do
    execute_single_target_attack(caster_state, target_id, opts, acid_terror_calculator(), %{})
  end

  defp acid_terror_calculator do
    case GameMode.mode() do
      :renewal -> &DamageCalculator.calculate_damage_ignoring_status_def/3
      :pre_renewal -> &DamageCalculator.calculate_damage_soft_defense_only/3
    end
  end

  defp execute_single_target_attack(
         caster_state,
         target_id,
         opts,
         damage_calculator,
         weapon_hit_metadata
       ) do
    execute_single_target_attack(
      caster_state,
      target_id,
      opts,
      damage_calculator,
      weapon_hit_metadata,
      &validate_physical_skill_target(&1, &2, Keyword.fetch!(opts, :skill_id))
    )
  end

  defp validate_physical_skill_target(_attacker, %{unit_type: :skill_unit}, 214), do: :ok

  defp validate_physical_skill_target(attacker, target, _skill_id),
    do: Targeting.validate_enemy(attacker, target)

  defp execute_single_target_attack(
         caster_state,
         target_id,
         opts,
         damage_calculator,
         weapon_hit_metadata,
         authorize_target
       ) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    report_hit? = Keyword.get(opts, :report_hit, false)
    hit_rate_bonus_pct = Keyword.get(opts, :hit_rate_bonus_pct, 0)

    calc_opts = physical_skill_calc_opts(caster_state, opts)
    validator_opts = physical_skill_validator_opts(opts)

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate(attacker, target, validator_opts),
         :ok <- authorize_target.(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}),
         :ok <-
           Targeting.validate_delivery(
             attacker,
             target,
             skill_id,
             Keyword.get(opts, :delivery, :direct)
           ),
         :ok <- StatusInterpreter.authorize_skill_damage(attacker, skill_id) do
      hit_opts = %{
        hit_divisions: Keyword.get(opts, :hit_divisions, 1),
        hit_rate_bonus_pct: hit_rate_bonus_pct,
        hit_rate_bonus_flat: Keyword.get(opts, :hit_rate_bonus_flat, 0),
        ignore_flee: Keyword.get(opts, :ignore_flee, false),
        fled: Keyword.get(opts, :fled, false),
        weapon_hit_metadata: weapon_hit_metadata,
        target_state: target_state,
        delivery: Keyword.get(opts, :delivery, :direct),
        dmg_type: Keyword.get(opts, :dmg_type, :physical)
      }

      {hit, coma?} =
        apply_skill_damage(
          attacker,
          {target_type, target_pid, target},
          skill_id,
          skill_level,
          {calc_opts, damage_calculator},
          hit_opts
        )

      result = logical_skill_result(hit, target_state, coma?)

      maybe_apply_skill_knockback(
        attacker,
        target,
        skill_id,
        hit,
        result,
        knockback_options(opts)
      )

      if report_hit?, do: {:ok, hit_report(hit, result)}, else: :ok
    else
      :suppressed -> suppressed_result(report_hit?)
      error -> error
    end
  end

  # A suppressed hit never reached the target, which therefore survives it.
  defp suppressed_result(false), do: :ok

  defp suppressed_result(true),
    do:
      {:ok,
       %{
         hit?: false,
         blocked?: false,
         connected?: false,
         damage: 0,
         target_survives?: true,
         coma?: false
       }}

  @doc """
  Executes a self/ground-centered splash skill against every offensive target in
  `radius` cells of `{x, y}`.

  Selects targets via `SplashTargets.select/4`, then runs each through the
  shared single-target damage path **without** the per-target attack-range
  gate — the radius already bounds the hit set. Each target rolls its own
  hit/flee check. Returns the ids of the targets the hit's additional effects
  apply to (`t:hit_report/0`'s `hit?`), for the skill's own riders.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals, or a one-arity
      function of the target's Chebyshev distance from `{x, y}` returning that
      percent, for a skill whose ratio falls off with distance (Magnum Break's
      inner and outer rings)
    - `:element` - optional attack-element override
    - `:critical`, `:critical_rate_bonus`, `:critical_max_weapon` - critical
      pre-roll options documented by `execute_skill_attack/3`
    - `:skip_crit` - skip the critical roll
    - `:hit_rate_bonus_pct` - relative percent bonus applied to each target's
      already-clamped hit rate, as documented by `execute_skill_attack/3`
      (default `0`)
    - `:hit_divisions` - each target's signed hit divisions, resolved as one
      logical attack per target (default `1`, see `execute_skill_attack/3`)
    - `:typed_results` - returns `{unit_type, unit_id}` refs instead of bare ids
      from the same execution (default `false`)
    - `:target_skill_units` - additionally admits targetable enemy trap cells
      reached by the splash (default `false`)
    - `:delivery` - how the splash reached each target (default `:direct`, see
      `execute_skill_attack/3`)
    - `:base_distance`, `:origin`, `:native_enabled`, `:native_target_types`, and
      `:native_requires_survival` - combined knockback options documented by
      `execute_skill_attack/3`
  """
  @spec execute_splash_attack(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer() | Ref.t()]
  def execute_splash_attack(caster_state, center, radius, opts) do
    execute_splash_with(
      caster_state,
      center,
      radius,
      opts,
      &DamageCalculator.calculate_damage/3
    )
  end

  @doc """
  Executes a physical splash owned by a supported player field.

  Selection and delivery both validate the exact source group. Connected
  targets are always returned as typed references for field follow-up effects.
  The field is the hits' actual source, so `:delivery` defaults to `:unit`.
  """
  @spec execute_field_splash_attack(
          struct(),
          {integer(), integer()},
          non_neg_integer(),
          Group.t(),
          keyword()
        ) :: [Ref.t()]
  def execute_field_splash_attack(caster_state, center, radius, %Group{} = group, opts) do
    case validate_field_skill_opts(group, opts) do
      :ok ->
        attacker = caster_state.__struct__.to_combatant(caster_state)
        {skill_id, skill_level, calc_opts} = multi_target_opts(opts)

        group
        |> SplashTargets.select_field(center, radius, attacker)
        |> hit_targets(
          attacker,
          skill_id,
          skill_level,
          calc_opts,
          %{
            ignore_flee?: Keyword.get(opts, :ignore_flee, false),
            typed_results?: true,
            knockback_options: knockback_options(opts),
            hit_rate_bonus_pct: Keyword.get(opts, :hit_rate_bonus_pct, 0),
            hit_rate_bonus_flat: Keyword.get(opts, :hit_rate_bonus_flat, 0),
            hit_divisions: Keyword.get(opts, :hit_divisions, 1),
            delivery: Keyword.get(opts, :delivery, :unit)
          },
          &Targeting.validate_field_target(group, &1, &2)
        )

      {:error, _reason} ->
        []
    end
  end

  @doc """
  Executes a forced-hit physical splash while omitting attacker cardfix only.

  This is the restricted delivery path for Venom Splasher. It preserves every
  interception and damage-delivery hook, including Auto Guard.
  """
  @spec execute_forced_no_card_splash(
          struct(),
          {integer(), integer()},
          non_neg_integer(),
          keyword()
        ) :: [integer() | Ref.t()]
  def execute_forced_no_card_splash(caster_state, center, radius, opts) do
    execute_splash_with(
      caster_state,
      center,
      radius,
      Keyword.put(opts, :ignore_flee, true),
      &DamageCalculator.calculate_damage_ignoring_attacker_cards/3
    )
  end

  defp execute_splash_with(caster_state, center, radius, opts, damage_calculator) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    {skill_id, skill_level, calc_opts} = multi_target_opts(opts)

    result_opts = %{
      ignore_flee?: Keyword.get(opts, :ignore_flee, false),
      typed_results?: Keyword.get(opts, :typed_results, false),
      knockback_options: knockback_options(opts),
      hit_rate_bonus_pct: Keyword.get(opts, :hit_rate_bonus_pct, 0),
      hit_rate_bonus_flat: Keyword.get(opts, :hit_rate_bonus_flat, 0),
      hit_divisions: Keyword.get(opts, :hit_divisions, 1),
      splash_center: center,
      delivery: Keyword.get(opts, :delivery, :direct)
    }

    selection_opts = Keyword.take(opts, [:target_skill_units])

    attacker.map_name
    |> SplashTargets.select(center, radius, attacker, false, selection_opts)
    |> hit_targets(
      attacker,
      skill_id,
      skill_level,
      {calc_opts, damage_calculator},
      result_opts
    )
  end

  @doc """
  Executes a line skill against the primary target plus every offensive
  target standing on the straight line of cells between the caster and it
  (inclusive of the target's own cell).

  Selects targets via `LineTargets.select/5`, then runs each through the
  shared single-target damage path **without** the per-target attack-range
  gate - the line already bounds the hit set. Each target rolls its own
  hit/flee check independently and resolves combined skill knockback once.
  Returns the ids of the targets it dealt damage to (the total before Devotion
  forwarding).

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll
    - `:critical`, `:critical_rate_bonus`, `:critical_max_weapon` - critical
      pre-roll options documented by `execute_skill_attack/3`
    - `:length` / `:width` - use an eight-direction lane with the supplied
      length and half-width, starting `:offset` rows out (default 0), hitting
      only targets in the caster's line of sight; without both, use the
      Bresenham line
    - `:hit_divisions` - each target's signed hit divisions (default `1`)
    - `:delivery` - `:direct` (default), `:splash` or `:area`: how the line
      reached each target, as the same-named `t:Targeting.delivery/0` whose
      primary is the line's own target
    - `:base_distance`, `:origin`, `:native_enabled`, `:native_target_types`, and
      `:native_requires_survival` - combined knockback options documented by
      `execute_skill_attack/3`
  """
  @spec execute_line_attack(struct(), integer() | Ref.t(), keyword()) :: [integer()]
  def execute_line_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    {skill_id, skill_level, calc_opts} = multi_target_opts(opts)

    case TargetResolver.resolve_target_position(target_id) do
      {:ok, target_type, {tx, ty, _map_name}} ->
        {sx, sy} = attacker.position
        primary = line_primary(target_type, target_id)

        attacker.map_name
        |> LineTargets.select(
          {sx, sy},
          {tx, ty},
          attacker,
          Keyword.take(opts, [:length, :width, :offset])
        )
        |> hit_targets(attacker, skill_id, skill_level, calc_opts, %{
          ignore_flee?: false,
          typed_results?: false,
          results: :damaged,
          knockback_options: knockback_options(opts),
          hit_rate_bonus_pct: Keyword.get(opts, :hit_rate_bonus_pct, 0),
          hit_rate_bonus_flat: Keyword.get(opts, :hit_rate_bonus_flat, 0),
          hit_divisions: Keyword.get(opts, :hit_divisions, 1),
          delivery: line_delivery(Keyword.get(opts, :delivery, :direct), primary)
        })

      {:error, _reason} ->
        []
    end
  end

  defp line_primary(_target_type, {_unit_type, _unit_id} = ref), do: ref
  defp line_primary(target_type, target_id), do: {target_type, target_id}

  defp line_delivery(:direct, _primary), do: :direct
  defp line_delivery(kind, primary) when kind in [:splash, :area], do: {kind, primary}

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
      :critical,
      :critical_rate_bonus,
      :critical_max_weapon,
      :bonus_atk,
      :envenom_atk,
      :base_atk_rate,
      :weight_atk,
      :ignore_size,
      :base_damage,
      :fixed_damage,
      :element,
      :skill_id,
      :skip_status_atk,
      :spirit_spheres
    ]) ++ shield_base_opts(caster_state, opts)
  end

  defp physical_skill_validator_opts(opts),
    do: Keyword.take(opts, [:skip_range]) ++ [projectile?: true]

  defp multi_target_opts(opts) do
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)

    calc_opts =
      Keyword.take(opts, [
        :skill_ratio,
        :skip_crit,
        :force_crit,
        :critical,
        :critical_rate_bonus,
        :critical_max_weapon,
        :skill_id,
        :element
      ])

    {skill_id, skill_level, calc_opts}
  end

  defp validate_field_skill_opts(%Group{skill_id: skill_id, level: level}, opts) do
    case {Keyword.fetch(opts, :skill_id), Keyword.fetch(opts, :skill_level)} do
      {{:ok, ^skill_id}, {:ok, ^level}} -> :ok
      _mismatch -> {:error, :field_skill_mismatch}
    end
  end

  defp hit_targets(
         targets,
         attacker,
         skill_id,
         skill_level,
         calc_opts,
         result_opts,
         authorize_target \\ fn _attacker, _target -> :ok end
       ) do
    Enum.flat_map(targets, fn {_unit_type, _target_id} = target_ref ->
      apply_splash_hit(
        attacker,
        target_ref,
        skill_id,
        skill_level,
        calc_opts,
        result_opts,
        authorize_target
      )
    end)
  end

  defp apply_splash_hit(
         attacker,
         target_ref,
         skill_id,
         skill_level,
         calc_opts,
         %{
           ignore_flee?: ignore_flee?,
           typed_results?: typed_results?,
           knockback_options: knockback_options,
           hit_rate_bonus_pct: hit_rate_bonus_pct
         } = result_opts,
         authorize_target
       ) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- authorize_target.(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}),
         :ok <-
           Targeting.validate_delivery(
             attacker,
             target,
             skill_id,
             Map.get(result_opts, :delivery, :direct)
           ),
         :ok <- StatusInterpreter.authorize_skill_damage(attacker, skill_id) do
      hit_opts = %{
        hit_divisions: Map.get(result_opts, :hit_divisions, 1),
        hit_rate_bonus_pct: hit_rate_bonus_pct,
        hit_rate_bonus_flat: Map.get(result_opts, :hit_rate_bonus_flat, 0),
        ignore_flee: ignore_flee?,
        weapon_hit_metadata: %{},
        target_state: target_state,
        delivery: Map.get(result_opts, :delivery, :direct)
      }

      calc_opts = resolve_distance_ratio(calc_opts, result_opts, target_state)

      {hit, coma?} =
        apply_skill_damage(
          attacker,
          {target_type, target_pid, target},
          skill_id,
          skill_level,
          calc_opts,
          hit_opts
        )

      result = logical_skill_result(hit, target_state, coma?)
      maybe_apply_skill_knockback(attacker, target, skill_id, hit, result, knockback_options)

      hit
      |> listed?(Map.get(result_opts, :results, :hit))
      |> connected_target_result(target_ref, typed_results?)
    else
      _ -> []
    end
  end

  # A splash skill whose per-level ratio depends on how far the victim stands
  # from the centre (Magnum Break's inner and outer rings) passes `:skill_ratio`
  # as a one-arity function of that Chebyshev distance. Every other caller
  # passes a plain percent, which falls through untouched.
  defp resolve_distance_ratio({opts, calculator}, result_opts, target_state) do
    with {cx, cy} <- Map.get(result_opts, :splash_center),
         ratio_fun when is_function(ratio_fun, 1) <- Keyword.get(opts, :skill_ratio) do
      distance = Geometry.chebyshev_distance(cx, cy, target_state.x, target_state.y)
      {Keyword.put(opts, :skill_ratio, ratio_fun.(distance)), calculator}
    else
      _not_distance_keyed -> {opts, calculator}
    end
  end

  defp resolve_distance_ratio(calc_opts, _result_opts, _target_state), do: calc_opts

  # A splash lists the targets its additional effects apply to; a line lists
  # those it dealt damage to (the reference sums `skill_attack`'s returns).
  defp listed?(hit, :hit), do: hit.class == :hit
  defp listed?(hit, :damaged), do: hit.damage > 0

  defp connected_target_result(false, _target_ref, _typed_results?), do: []
  defp connected_target_result(true, target_ref, true), do: [target_ref]
  defp connected_target_result(true, target_ref, false), do: [elem(target_ref, 1)]

  @doc """
  Executes a single-target BF_MISC skill (trap) from a caster against a target.

  Routes the caller-supplied `:base_damage` through `MiscDamageCalculator`
  (the target's cards, the skill rates and the element step; no DEF or MDEF), broadcasts a `ZC_NOTIFY_SKILL`
  packet, then applies the misc damage. Unlike the magic path there is no
  caster-target range check: a trap fires on contact regardless of where its
  owner stands. Hostility (owner/ally exclusion) is decided by the trap's
  `on_touch` before this is called.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:base_damage` - the skill's per-level base damage (required)
    - `:element` - the skill's attack element (default `:neutral`)
    - `:hit_divisions` - signed divisions of the one calculated hit (default `1`);
      the packet shows the normalized count
    - `:weapon_flag` - the hit also counts as a weapon attack (Throw Stone), for
      every check that reads its battle flag (default `false`)
    - `:bypass_reductions` - deliver without magic reduction or absorbing
      statuses (pre-renewal Gravitation Field, Gloria Domini) (default `false`)
    - `:report_hit` - return settled damage and logical target survival (default `false`),
      without waiting for the target's asynchronous HP mutation
    - `:delivery` - how the hit reached the target (default `:direct`, see
      `execute_skill_attack/3`)
    - `:fix_damage` - deal it as `battle_fix_damage` does (default `false`): the
      base is dealt as is, without the misc card, skill-rate and element steps; it
      stops no walking target and runs no additional or counter effects, so it
      carries no equipment procs
    - `:base_distance`, `:origin`, `:native_enabled`, `:native_target_types`, and
      `:native_requires_survival` - combined knockback options documented by
      `execute_skill_attack/3`

  A hit the caster's own Gravitation Field suppresses reports `hit?: false`
  like `execute_skill_attack/3`; Gravitation Field's own ticks are exempt.
  """
  @spec execute_misc_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok | {:ok, hit_report()} | {:error, atom()}
  def execute_misc_attack(caster_state, target_id, opts) do
    execute_misc_attack_with(caster_state, target_id, opts, &Targeting.validate_enemy/2)
  end

  @doc """
  Executes one misc hit owned by a supported player field.

  The exact group authorizes the target at delivery time; all misc calculation,
  hooks, packets, and settlement remain shared with `execute_misc_attack/3`.
  The field is the hit's actual source, so `:delivery` defaults to `:unit`.
  """
  @spec execute_field_misc_attack(struct(), Ref.t(), Group.t(), keyword()) ::
          :ok | {:ok, hit_report()} | {:error, atom()}
  def execute_field_misc_attack(caster_state, target_ref, %Group{} = group, opts) do
    with :ok <- validate_field_skill_opts(group, opts) do
      execute_misc_attack_with(
        caster_state,
        target_ref,
        Keyword.put_new(opts, :delivery, :unit),
        &Targeting.validate_field_target(group, &1, &2)
      )
    end
  end

  defp execute_misc_attack_with(caster_state, target_ref, opts, authorize_target) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)

    report_hit? = Keyword.get(opts, :report_hit, false)

    case apply_misc_hit(
           attacker,
           target_ref,
           skill_id,
           skill_level,
           element,
           base_damage,
           Keyword.get(opts, :hit_divisions, 1),
           %{
             authorize_target: authorize_target,
             weapon_flag?: Keyword.get(opts, :weapon_flag, false),
             owner_derived_trap?: false,
             report_hit?: report_hit?,
             bypass_reductions?: Keyword.get(opts, :bypass_reductions, false),
             knockback_options: knockback_options(opts),
             delivery: Keyword.get(opts, :delivery, :direct),
             fix_damage?: Keyword.get(opts, :fix_damage, false)
           }
         ) do
      :suppressed -> suppressed_result(report_hit?)
      result -> result
    end
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
    - `:hit_divisions` - signed divisions of each target's one calculated hit
      (default `1`); the packet shows the normalized count
    - `:split` - divide one supplied base by the selected living-enemy count
      before target-specific damage processing (default `false`)
    - `:target_skill_units` - include only live targetable traps (default `false`)
    - `:shoot_range_los` - require projectile line of sight from the splash center
    - `:delivery` - how the splash reached each target (default `:direct`, see
      `execute_skill_attack/3`); the split divisor counts every selected target,
      refused or not
    - `:base_distance`, `:origin`, `:native_enabled`, `:native_target_types`, and
      `:native_requires_survival` - combined knockback options documented by
      `execute_skill_attack/3`
  """
  @spec execute_misc_splash(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_misc_splash(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)
    target_skill_units? = Keyword.get(opts, :target_skill_units, false)

    targets =
      SplashTargets.select(attacker.map_name, center, radius, attacker, false,
        target_skill_units: target_skill_units?,
        shoot_range_los: Keyword.get(opts, :shoot_range_los, false)
      )

    base_damage = split_base_damage(base_damage, targets, Keyword.get(opts, :split, false))

    Enum.flat_map(targets, fn {_unit_type, target_id} = target_ref ->
      case apply_misc_hit(
             attacker,
             target_ref,
             skill_id,
             skill_level,
             element,
             base_damage,
             Keyword.get(opts, :hit_divisions, 1),
             %{
               authorize_target: &validate_trap_splash_enemy/2,
               owner_derived_trap?: target_skill_units?,
               knockback_options: knockback_options(opts),
               delivery: Keyword.get(opts, :delivery, :direct)
             }
           ) do
        :ok -> [target_id]
        _ -> []
      end
    end)
  end

  @doc """
  Executes a split-capable misc splash owned by a supported player field.

  The exact group authorizes selection, the split divisor, and each actual
  delivery. The function preserves the existing misc splash geometry and
  settlement behavior and returns after dispatching all eligible targets. The
  field is the hits' actual source, so `:delivery` defaults to `:unit`; the
  split divisor counts the authorized targets before that check.
  """
  @spec execute_field_misc_splash(
          struct(),
          {integer(), integer()},
          non_neg_integer(),
          Group.t(),
          keyword()
        ) :: :ok
  def execute_field_misc_splash(caster_state, center, radius, %Group{} = group, opts) do
    if validate_field_skill_opts(group, opts) == :ok do
      attacker = caster_state.__struct__.to_combatant(caster_state)
      skill_id = group.skill_id
      skill_level = group.level
      authorize_target = &Targeting.validate_field_target(group, &1, &2)

      targets =
        group
        |> SplashTargets.select_field(center, radius, attacker,
          shoot_range_los: Keyword.get(opts, :shoot_range_los, false)
        )
        |> eligible_misc_targets(attacker, skill_id, authorize_target)

      base_damage =
        opts
        |> Keyword.fetch!(:base_damage)
        |> split_base_damage(targets, Keyword.get(opts, :split, false))

      Enum.each(targets, fn target_ref ->
        apply_misc_hit(
          attacker,
          target_ref,
          skill_id,
          skill_level,
          Keyword.get(opts, :element, :neutral),
          base_damage,
          Keyword.get(opts, :hit_divisions, 1),
          %{
            authorize_target: authorize_target,
            owner_derived_trap?: false,
            knockback_options: knockback_options(opts),
            delivery: Keyword.get(opts, :delivery, :unit)
          }
        )
      end)
    end

    :ok
  end

  defp eligible_misc_targets(targets, attacker, skill_id, authorize_target) do
    Enum.filter(targets, fn target_ref ->
      with {:ok, _target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
           :ok <- TargetResolver.ensure_targetable(target_state, target_type),
           {:ok, target} <- misc_target_combatant(target_state, false),
           :ok <- authorize_target.(attacker, target),
           :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}) do
        true
      else
        _ineligible -> false
      end
    end)
  end

  defp split_base_damage(base_damage, [], true), do: base_damage
  defp split_base_damage(base_damage, targets, true), do: div(base_damage, length(targets))
  defp split_base_damage(base_damage, _targets, false), do: base_damage

  defp apply_misc_hit(
         attacker,
         target_ref,
         skill_id,
         skill_level,
         element,
         base_damage,
         hit_divisions,
         misc_opts
       ) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         {:ok, target} <-
           misc_target_combatant(target_state, misc_opts.owner_derived_trap?),
         target_id <- target.unit_id,
         :ok <- misc_opts.authorize_target.(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}),
         :ok <- Targeting.validate_delivery(attacker, target, skill_id, misc_opts.delivery),
         :ok <- StatusInterpreter.authorize_skill_damage(attacker, skill_id),
         range = SkillRange.classify(attacker, target, skill_id, skill_level),
         attack_flag = misc_attack_flag(range, misc_opts),
         {:ok, %{damage: damage}} <-
           MiscDamageCalculator.calculate_misc_damage(
             attacker,
             target,
             misc_damage_opts(base_damage, element, skill_id, attack_flag, misc_opts)
           ) do
      {damage, divisions} = DamageShared.normalize_damage_divisions(damage, hit_divisions)
      coma? = decide_coma(attacker, target, damage)

      immediate? = EquipProcDispatch.immediate?(skill_id, misc_opts.delivery)

      hit_info = %{
        dmg_type: :misc,
        is_short: range == :short,
        element: element,
        skill_id: skill_id,
        skill_level: skill_level,
        coma?: coma?,
        bypass_reductions: Map.get(misc_opts, :bypass_reductions?, false),
        div: divisions
      }

      hit_info =
        if Map.get(misc_opts, :fix_damage?, false),
          do: Map.merge(hit_info, %{walk_delay?: false, div: 0}),
          else:
            Map.put(
              hit_info,
              :proc,
              EquipProcDispatch.spec(attacker, target, target_state, attack_flag,
                divisions: divisions,
                skill_id: skill_id,
                immediate?: immediate?
              )
            )

      source = damage_source(attacker, target_type)

      if damage > 1 do
        EquipVanish.after_hit(attacker, target, target_pid, attack_flag)
      end

      {damage, hit_info} =
        DamageApplication.prepare_unit_damage(
          target_type,
          target_id,
          damage,
          hit_info,
          source
        )

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage,
          div: DamageShared.display_divisions(attacker, hit_info, damage, divisions)
        )

      DamageApplication.broadcast_nearby(target, packet)

      delivery =
        DamageApplication.apply_unit_damage(
          target_type,
          target_pid,
          target_id,
          damage,
          hit_info,
          source
        )

      if delivered?(delivery), do: OnHitEffects.after_hit(hit_info, damage)

      hit = connected_hit(damage, hit_info, divisions, immediate?)
      result = logical_skill_result(hit, target_state, coma?)

      maybe_apply_skill_knockback(
        attacker,
        target,
        skill_id,
        hit,
        result,
        misc_opts.knockback_options
      )

      EquipProcDispatch.dispatch_delivered(delivery, hit_info, damage)

      if delivery == :ok and Map.get(misc_opts, :report_hit?, false),
        do: {:ok, hit_report(hit, result)},
        else: delivery
    end
  end

  defp prepare_staged_skill_hit(
         {attacker, target_type, target},
         skill_id,
         skill_level,
         calc_opts,
         hit_opts
       ) do
    %{
      hit_divisions: hit_divisions,
      knockback_options: knockback_options
    } = hit_opts

    {hit_result, calc_opts} = skill_hit_result(attacker, target, skill_id, calc_opts, hit_opts)
    skill = {skill_id, skill_level}

    case {hit_result, fled_damage(hit_result, attacker, target, skill, calc_opts, hit_opts)} do
      {:miss, :none} ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_miss_packet(attacker, target)
        )

        {:ok, :miss}

      {:perfect_dodge, _fled} ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_perfect_dodge_packet(attacker, target)
        )

        {:ok, :miss}

      {_connected, fled} ->
        long? = long_range?(attacker, target, skill_id, skill_level)
        calc_opts = Keyword.put(calc_opts, :ranged, long?)

        case fled_or_calculated(fled, attacker, target, calc_opts) do
          {:ok, damage_result} ->
            {damage_result, divisions} = normalize_divisions(damage_result, hit_divisions)

            {:ok,
             %PreparedHit{
               attacker: attacker,
               target_type: target_type,
               target: target,
               skill_id: skill_id,
               skill_level: skill_level,
               damage_result: damage_result,
               divisions: divisions,
               element: physical_attack_element(attacker, calc_opts),
               long?: long?,
               coma?: decide_coma(attacker, target, damage_result.damage),
               knockback_options: knockback_options
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

  defp validate_trap_splash_enemy(_attacker, %{unit_type: :skill_unit}), do: :ok

  defp validate_trap_splash_enemy(attacker, target),
    do: Targeting.validate_enemy(attacker, target)

  defp misc_damage_opts(base_damage, element, skill_id, attack_flag, misc_opts) do
    opts = [
      base_damage: base_damage,
      element: element,
      skill_id: skill_id,
      attack_flag: attack_flag
    ]

    if Map.get(misc_opts, :fix_damage?, false),
      do: Keyword.put(opts, :fixed_damage, base_damage),
      else: opts
  end

  # A weapon-flagged misc hit (Throw Stone) also counts as a weapon attack.
  defp misc_attack_flag(range, %{weapon_flag?: true}),
    do: BattleFlags.build(:misc, range, true) ||| BattleFlags.type_bit(:weapon)

  defp misc_attack_flag(range, _misc_opts), do: BattleFlags.build(:misc, range, true)

  # Resolves one logical attack: the target's weapon interceptions, one
  # hit/flee roll, one damage calculation normalized over the attack's signed
  # divisions, and its delivery. A miss or interception broadcasts its own
  # feedback. Returns the resolved hit and the target's coma decision. A flee
  # the caller rolled that deals nothing never reaches the interceptions, which
  # only act on damage.
  @spec apply_skill_damage(
          struct(),
          {:player | :mob | :homunculus | :skill_unit, pid(), struct()},
          integer(),
          pos_integer(),
          calc_context(),
          map()
        ) :: {resolved_hit(), boolean()}
  defp apply_skill_damage(
         attacker,
         {_target_type, _target_pid, target} = target_context,
         skill_id,
         skill_level,
         calc_context,
         %{fled: true} = hit_opts
       ) do
    case fled_damage(:miss, attacker, target, {skill_id, skill_level}, calc_context, hit_opts) do
      :none ->
        {missed_hit(hit_opts), missed_coma(attacker, target_context)}

      {:ok, _fled} ->
        intercept_or_resolve(
          attacker,
          target_context,
          skill_id,
          skill_level,
          calc_context,
          hit_opts
        )
    end
  end

  defp apply_skill_damage(
         attacker,
         target_context,
         skill_id,
         skill_level,
         calc_context,
         hit_opts
       ),
       do:
         intercept_or_resolve(
           attacker,
           target_context,
           skill_id,
           skill_level,
           calc_context,
           hit_opts
         )

  defp intercept_or_resolve(
         attacker,
         {target_type, _target_pid, target} = target_context,
         skill_id,
         skill_level,
         calc_context,
         hit_opts
       ) do
    case weapon_interception(attacker, target_type, target, hit_opts) do
      :blocked ->
        {missed_hit(hit_opts), missed_coma(attacker, target_context)}

      :intercepted ->
        {missed_hit(hit_opts), false}

      :continue ->
        resolve_skill_hit(
          attacker,
          target_context,
          skill_id,
          skill_level,
          calc_context,
          hit_opts
        )
    end
  end

  defp weapon_interception(attacker, target_type, target, hit_opts) do
    if Map.get(hit_opts, :dmg_type, :physical) == :physical,
      do:
        weapon_hit_intercepted?(
          attacker,
          target_type,
          target,
          Map.fetch!(hit_opts, :weapon_hit_metadata)
        ),
      else: :continue
  end

  # An attack that reaches the target for nothing (a miss, a perfect dodge, a
  # shield block) still rolls the attacker's coma; returns that decision.
  defp missed_coma(attacker, {target_type, target_pid, target}),
    do:
      DamageApplication.apply_missed_coma(
        attacker,
        target,
        target_pid,
        damage_source(attacker, target_type)
      )

  defp missed_hit(%{hit_divisions: hit_divisions}) do
    {0, divisions} = DamageShared.normalize_damage_divisions(0, hit_divisions)
    %{hit?: false, damage: 0, taken: 0, divisions: divisions, class: :miss}
  end

  # A delivered hit: `taken` is what the target lost, the total and class come
  # from the prepared hit (the total before Devotion forwarding).
  defp connected_hit(taken, hit_info, divisions, immediate?) do
    %{
      hit?: true,
      damage: DamageShared.settled_total(hit_info, taken),
      taken: taken,
      divisions: divisions,
      class: DamageShared.hit_class(hit_info, taken, immediate?)
    }
  end

  # A weapon-class skill hit passes through the target's `before_weapon_hit`
  # interception statuses (Guard) exactly as a basic attack does, but tagged
  # `basic_attack?: false` so basic-attack-only stances (Auto Counter, Blade
  # Stop) stay inert. An interception cancels this hit entirely: no hit roll and
  # no damage. A shield block (Guard) still broadcasts a zero-damage "guarded"
  # packet so the attacker sees the swing land for 0 and returns `:blocked`;
  # other interceptions own their own feedback effect, stay silent and return
  # `:intercepted`.
  # Magic and misc skills never call this path, nor does a weapon-calculated hit
  # delivered as misc, so they can never be blocked.
  @spec weapon_hit_intercepted?(
          struct(),
          :player | :mob | :homunculus | :skill_unit,
          struct(),
          map()
        ) :: :blocked | :intercepted | :continue
  defp weapon_hit_intercepted?(attacker, target_type, target, metadata) do
    attack_info =
      Map.merge(
        %{
          attacker: {attacker.unit_type, attacker.unit_id},
          target: {target_type, target.unit_id},
          attacker_boss?: attacker.class == :boss,
          attacker_root_level: 0,
          attacker_position: attacker.position,
          attacker_short?: attacker.attack_range <= 3,
          distance: cell_distance(attacker, target),
          basic_attack?: false
        },
        metadata
      )

    case StatusInterpreter.before_weapon_hit(target_type, target.unit_id, attack_info) do
      {:intercept, :blocked} ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_guard_packet(attacker, target)
        )

        :blocked

      {:intercept, _result} ->
        :intercepted

      :continue ->
        :continue
    end
  end

  @spec cell_distance(struct(), struct()) :: non_neg_integer()
  defp cell_distance(%{position: {ax, ay}}, %{position: {tx, ty}}),
    do: max(abs(ax - tx), abs(ay - ty))

  defp cell_distance(_attacker, _target), do: 0

  defp resolve_skill_hit(
         attacker,
         {_target_type, _target_pid, target} = target_context,
         skill_id,
         skill_level,
         calc_context,
         hit_opts
       ) do
    {hit_result, calc_context} =
      skill_hit_result(attacker, target, skill_id, calc_context, hit_opts)

    skill = {skill_id, skill_level}

    case {hit_result, fled_damage(hit_result, attacker, target, skill, calc_context, hit_opts)} do
      {:miss, {:ok, fled}} ->
        {calc_opts, _calculator} = damage_calculation(calc_context)

        deliver_skill_hit(
          attacker,
          target_context,
          skill_id,
          skill_level,
          {calc_opts, fn _attacker, _target, _opts -> {:ok, fled} end},
          hit_opts
        )

      {:miss, :none} ->
        unless Map.get(hit_opts, :fled, false) do
          DamageApplication.broadcast_nearby(
            target,
            PacketFactory.build_miss_packet(attacker, target)
          )
        end

        {missed_hit(hit_opts), missed_coma(attacker, target_context)}

      {:perfect_dodge, _fled} ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_perfect_dodge_packet(attacker, target)
        )

        {missed_hit(hit_opts), missed_coma(attacker, target_context)}

      {:hit, _fled} ->
        deliver_skill_hit(
          attacker,
          target_context,
          skill_id,
          skill_level,
          calc_context,
          hit_opts
        )
    end
  end

  # A fled weapon attack still deals what follows its hit block
  # (`DamageCalculator.calculate_fled_damage/3`) and connects when that,
  # repeated over its divisions, totals at least 1. Returns that raw result, or
  # `:none` when it deals nothing or the roll was not a flee.
  defp fled_damage(:miss, attacker, target, {skill_id, skill_level}, calc_context, hit_opts) do
    calc_opts =
      calc_context
      |> calc_opts()
      |> Keyword.put(:ranged, long_range?(attacker, target, skill_id, skill_level))

    {:ok, fled} = DamageCalculator.calculate_fled_damage(attacker, target, calc_opts)

    case normalize_divisions(fled, hit_opts.hit_divisions) do
      {%{damage: damage}, _divisions} when damage >= 1 -> {:ok, fled}
      _nothing -> :none
    end
  end

  defp fled_damage(_hit_result, _attacker, _target, _skill, _calc_context, _hit_opts),
    do: :none

  defp fled_or_calculated({:ok, fled}, _attacker, _target, _calc_opts), do: {:ok, fled}

  defp fled_or_calculated(:none, attacker, target, calc_opts),
    do: DamageCalculator.calculate_damage(attacker, target, calc_opts)

  # Of all skills only Sacrifice can be perfect-dodged, before anything else.
  # The critical is decided next and always hits; only a non-critical hit that
  # does not ignore flee rolls its accuracy. Returns the calculation context
  # with the critical decided.
  defp skill_hit_result(attacker, target, skill_id, calc_context, hit_opts) do
    critical = fn -> skill_critical?(attacker, target, calc_opts(calc_context)) end
    target_stats = skill_flee_stats(target, skill_id)

    result =
      cond do
        Map.get(hit_opts, :fled, false) -> :miss
        hit_opts.ignore_flee -> forced_hit_result(target_stats, critical)
        true -> rolled_hit_result(attacker, target_stats, critical, hit_opts)
      end

    case result do
      :critical -> {:hit, decided_critical(calc_context, true)}
      other -> {other, decided_critical(calc_context, false)}
    end
  end

  defp forced_hit_result(target_stats, critical) do
    cond do
      HitCalculations.perfect_dodge_triggered?(target_stats) -> :perfect_dodge
      critical.() -> :critical
      true -> :hit
    end
  end

  defp rolled_hit_result(attacker, target_stats, critical, hit_opts) do
    attacker
    |> hit_stats(hit_opts.hit_rate_bonus_pct, hit_opts.hit_rate_bonus_flat)
    |> Map.put(:critical, critical)
    |> HitCalculations.calculate_hit_result(target_stats)
  end

  # A critical skill (`critical: true`) rolls its chance with its own bonus; a
  # forced critical (Auto Counter's strike) stays; any other skill never crits.
  defp skill_critical?(attacker, target, opts) do
    cond do
      Keyword.get(opts, :critical, false) ->
        bonus = Keyword.get(opts, :critical_rate_bonus, 0) * 10
        Critical.roll?(attacker, target, skill_bonus: bonus)

      Keyword.get(opts, :force_crit, false) ->
        true

      true ->
        false
    end
  end

  defp calc_opts({opts, _calculator}), do: opts
  defp calc_opts(opts), do: opts

  defp decided_critical({opts, calculator}, critical?),
    do: {decided_critical(opts, critical?), calculator}

  defp decided_critical(opts, critical?) do
    opts
    |> Keyword.drop([:critical, :force_crit, :skip_crit])
    |> Keyword.put(if(critical?, do: :force_crit, else: :skip_crit), true)
  end

  defp deliver_skill_hit(
         attacker,
         {_target_type, _target_pid, target} = target_context,
         skill_id,
         skill_level,
         calc_context,
         hit_opts
       ) do
    %{hit_divisions: hit_divisions} = hit_opts
    {calc_opts, damage_calculator} = damage_calculation(calc_context)
    element = physical_attack_element(attacker, calc_opts)
    long? = long_range?(attacker, target, skill_id, skill_level)
    calc_opts = Keyword.put(calc_opts, :ranged, long?)

    case damage_calculator.(attacker, target, calc_opts) do
      {:ok, damage_result} ->
        {damage_result, divisions} = normalize_divisions(damage_result, hit_divisions)
        coma? = decide_coma(attacker, target, damage_result.damage)

        hit =
          deliver_calculated_skill_hit(
            attacker,
            target_context,
            skill_id,
            skill_level,
            damage_result,
            %{
              divisions: divisions,
              element: element,
              long?: long?,
              coma?: coma?,
              target_state: Map.get(hit_opts, :target_state),
              delivery: Map.get(hit_opts, :delivery, :direct),
              dmg_type: Map.get(hit_opts, :dmg_type, :physical)
            }
          )

        {hit, coma?}

      {:error, _reason} ->
        {missed_hit(hit_opts), false}
    end
  end

  # One range classification per hit feeds the calculator's range channels and
  # the delivered hit.
  defp long_range?(attacker, target, skill_id, skill_level),
    do: SkillRange.classify(attacker, target, skill_id, skill_level) == :long

  # The one calculated damage becomes the attack's logical total before any
  # mutable target status sees it; the packet shows the normalized count.
  defp normalize_divisions(damage_result, hit_divisions),
    do: DamageCalculator.normalize_divisions(damage_result, hit_divisions)

  defp damage_source(%{unit_type: unit_type, unit_id: unit_id}, :player),
    do: {unit_type, unit_id}

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
         hit_metadata
       ) do
    %{divisions: divisions, element: element, long?: long?, coma?: coma?} = hit_metadata
    dmg_type = Map.get(hit_metadata, :dmg_type, :physical)
    immediate? = EquipProcDispatch.immediate?(skill_id, hit_metadata.delivery)

    attack_flag =
      BattleFlags.build(flag_type(dmg_type), if(long?, do: :long, else: :short), true)

    hit_info = %{
      dmg_type: dmg_type,
      is_short: not long?,
      element: element,
      skill_id: skill_id,
      skill_level: skill_level,
      coma?: coma?,
      div: divisions,
      proc:
        EquipProcDispatch.spec(attacker, target, hit_metadata.target_state, attack_flag,
          divisions: divisions,
          skill_id: skill_id,
          immediate?: immediate?,
          arrow_attack?: immediate? and arrow_skill?(attacker, skill_id, hit_metadata.delivery)
        )
    }

    hit_info = DamageApplication.mark_infinite_defense(hit_info, damage_result)

    source = damage_source(attacker, target_type)

    if damage_result.damage > 1 do
      EquipVanish.after_hit(attacker, target, target_pid, attack_flag)
    end

    {damage, hit_info} =
      DamageApplication.prepare_unit_damage(
        target_type,
        target.unit_id,
        damage_result.damage,
        hit_info,
        source
      )

    packet =
      PacketFactory.build_skill_damage_packet(
        attacker,
        target,
        skill_id,
        skill_level,
        %{damage_result | damage: damage},
        div: DamageShared.display_divisions(attacker, hit_info, damage, divisions)
      )

    DamageApplication.broadcast_nearby(target, packet)

    delivery =
      DamageApplication.apply_unit_damage(
        target_type,
        target_pid,
        target.unit_id,
        damage,
        hit_info,
        source
      )

    if delivered?(delivery) do
      OnHitEffects.after_hit(attacker, target, EquipProcDispatch.hit_event(hit_info, damage),
        attack_flag: attack_flag,
        skill_id: skill_id
      )
    end

    EquipProcDispatch.dispatch_delivered(delivery, hit_info, damage)
    connected_hit(damage, hit_info, divisions, immediate?)
  end

  defp delivered?(delivery), do: delivery == :ok or match?({:local_effects, _effects}, delivery)

  defp flag_type(:physical), do: :weapon
  defp flag_type(:misc), do: :misc

  # The arrow-attack state holds only while a player's arrow skill resolves its
  # own cast: an arrow skill's immediate hits from the caster itself.
  defp arrow_skill?(%{unit_type: :player}, skill_id, delivery) when delivery != :unit,
    do: match?({:ok, %{requires_ammo: true}}, Catalog.by_id(skill_id))

  defp arrow_skill?(_attacker, _skill_id, _delivery), do: false

  defp damage_calculation({calc_opts, damage_calculator}),
    do: {calc_opts, damage_calculator}

  defp damage_calculation(calc_opts),
    do: {calc_opts, &DamageCalculator.calculate_damage/3}

  defp physical_attack_element(attacker, calc_opts) do
    Keyword.get(calc_opts, :element) ||
      DamageShared.endow_element(
        ModifierCalculator.get_battle_modifiers(attacker.unit_type, attacker.unit_id)
      ) || attacker.weapon.element
  end

  defp decide_coma(attacker, target, _damage), do: EquipComa.trigger?(attacker, target)

  # Whether the target outlives a connected hit; the knockback stage's view.
  defp logical_skill_result(%{hit?: hit?, taken: taken}, target_state, coma?) do
    %{
      hit?: hit?,
      target_survives?:
        coma? or not hit? or taken == 0 or known_target_survives?(target_state, taken),
      coma?: coma?
    }
  end

  defp hit_report(hit, result) do
    Map.merge(result, %{
      hit?: hit.class == :hit,
      blocked?: hit.class == :block,
      connected?: hit.hit?,
      damage: hit.damage
    })
  end

  defp known_target_survives?(target_state, damage) do
    case target_hp(target_state) do
      hp when is_integer(hp) -> hp > damage
      nil -> false
    end
  end

  # A hit pushes only when it dealt at least one damage per division, except
  # Palm Strike, which pushes whenever it connected.
  defp maybe_apply_skill_knockback(
         attacker,
         target,
         skill_id,
         %{hit?: true, damage: damage, divisions: divisions},
         result,
         opts
       )
       when damage >= divisions or skill_id == @palm_strike_id do
    _ = Knockback.skill(attacker, target, skill_id, result, opts)
    :ok
  end

  defp maybe_apply_skill_knockback(_attacker, _target, _skill_id, _hit, _result, _opts), do: :ok

  defp knockback_options(opts) do
    Keyword.take(opts, [
      :base_distance,
      :origin,
      :native_enabled,
      :native_target_types,
      :native_requires_survival,
      :equipment_blow
    ])
  end

  defp target_hp(%{stats: %{current_state: %{hp: hp}}}) when is_integer(hp), do: hp
  defp target_hp(%{hp: hp}) when is_integer(hp), do: hp
  defp target_hp(_target_state), do: nil

  # The cast skill's own accuracy bonus and the attacker's standing bonus stay
  # separate: they compound on the clamped hit rate rather than summing.
  defp hit_stats(attacker, hit_rate_bonus_pct, hit_rate_bonus_flat) do
    %{
      hit: attacker.combat_stats.hit,
      char_id: attacker.unit_id,
      perfect_hit: EquipmentBonuses.perfect_hit_rate(attacker),
      skill_hit_rate_bonus_pct: hit_rate_bonus_pct,
      hit_rate_bonus_pct: Map.get(attacker.combat_stats, :hit_rate_bonus_pct, 0),
      hit_rate_bonus_flat: hit_rate_bonus_flat
    }
  end

  defp skill_flee_stats(target, skill_id) do
    %{
      flee: target.combat_stats.flee,
      perfect_dodge: if(skill_id == @sacrifice, do: target.combat_stats.perfect_dodge, else: 0),
      unit_id: target.unit_id
    }
  end
end
