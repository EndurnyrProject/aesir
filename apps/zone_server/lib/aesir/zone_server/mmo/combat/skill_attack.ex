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
      :display_hits,
      :element,
      :ranged,
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

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutobonus
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.EquipVanish
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.LineTargets
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
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
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @max_uint32 0xFFFF_FFFF

  @typep damage_calculator ::
           (struct(), struct(), keyword() -> {:ok, map()} | {:error, atom()})

  # The damage-calculation context threaded down to `apply_skill_damage/7`:
  # either bare calculator options (implying `DamageCalculator.calculate_damage/3`)
  # or an explicit `{opts, calculator}` pair for skills using another formula.
  @typep calc_context :: keyword() | {keyword(), damage_calculator()}
  @typep coma_decision :: :unchecked | boolean()

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
      prepared `:damage`, `:target_survives?`, and the logical `:coma?`
      decision. With `:hit_count` greater than `1`, damage is summed and `hit?`
      is `true` if any hit connected.
      Default `false`, so existing callers see no change. (default `false`)
    - `:ignore_flee` - when `true`, skips the hit/flee roll while retaining
      interception, validation, damage preparation, and delivery, so the strike
      always connects (e.g. Occult Impaction, Asura Strike) (default `false`)
    - `:simple_defense` - when `true`, the target's DEF is dropped as a flat
      hard+soft subtraction instead of the renewal DEF curve (e.g. Asura
      Strike) (default `false`)
    - `:ignore_defense` - when `true`, the target's DEF is skipped entirely
      (classic Asura Strike) (default `false`)
    - `:ranged` - forces `is_short: false` in the delivered hit_info,
      overriding the caster's melee attack-range classification, for a skill
      whose reach is short but whose damage type is renewal's ranged physical
      class (e.g. a thrown spear) (default `false`)
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

  ## Returns
    - :ok if the skill was dispatched (regardless of whether any hit
      connected), when `:report_hit` is not set
    - `{:ok, %{hit?: boolean, damage: non_neg_integer,
      target_survives?: boolean, coma?: boolean}}` when `:report_hit` is `true`
    - {:error, reason} if the target was invalid, friendly, dead, or out of range
  """
  @spec execute_skill_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok,
             %{
               hit?: boolean(),
               damage: non_neg_integer(),
               target_survives?: boolean(),
               coma?: boolean()
             }}
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
  match the authoritative group.
  """
  @spec execute_field_skill_attack(struct(), Ref.t(), Group.t(), keyword()) ::
          :ok
          | {:ok,
             %{
               hit?: boolean(),
               damage: non_neg_integer(),
               target_survives?: boolean(),
               coma?: boolean()
             }}
          | {:error, atom()}
  def execute_field_skill_attack(caster_state, target_ref, %Group{} = group, opts) do
    calculator = calculator(opts)

    with :ok <- validate_field_skill_opts(group, opts) do
      execute_single_target_attack(
        caster_state,
        target_ref,
        opts,
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
          | {:ok,
             %{
               hit?: boolean(),
               damage: non_neg_integer(),
               target_survives?: boolean(),
               coma?: boolean()
             }}
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

  This narrow entry forces neutral long-range damage and marks only Auto Guard
  as exempt. Every other weapon interception and ordinary damage-delivery hook
  remains active.
  """
  @spec execute_forced_no_card_attack(struct(), integer() | Ref.t(), keyword()) ::
          :ok
          | {:ok,
             %{
               hit?: boolean(),
               damage: non_neg_integer(),
               target_survives?: boolean(),
               coma?: boolean()
             }}
          | {:error, atom()}
  def execute_forced_no_card_attack(caster_state, target_id, opts) do
    opts = Keyword.merge(opts, ignore_flee: true, element: :neutral, ranged: true)

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

    with {:ok, _target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate(attacker, target, validator_opts),
         :ok <- Targeting.validate_enemy(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}) do
      if weapon_hit_intercepted?(attacker, target_type, target, %{}) do
        {:ok, :miss}
      else
        prepare_staged_skill_hit(
          {attacker, target_type, target},
          skill_id,
          skill_level,
          calc_opts,
          %{
            display_hits: display_hits,
            hit_rate_bonus_pct: hit_rate_bonus_pct,
            ignore_flee: Keyword.get(opts, :ignore_flee, false),
            ranged: Keyword.get(opts, :ranged, false),
            knockback_options: knockback_options(opts)
          }
        )
      end
    end
  end

  @doc "Delivers one opaque hit returned by `prepare_staged_skill_attack/3`."
  @spec deliver_prepared_skill_hit(PreparedHit.t()) :: :ok
  def deliver_prepared_skill_hit(%PreparedHit{} = prepared) do
    %PreparedHit{
      attacker: prepared_attacker,
      target_type: target_type,
      target: prepared_target,
      skill_id: skill_id,
      skill_level: skill_level,
      damage_result: damage_result,
      display_hits: display_hits,
      element: element,
      ranged: ranged?,
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
      damage =
        deliver_calculated_skill_hit(
          attacker,
          {target_type, target_pid, target},
          skill_id,
          skill_level,
          damage_result,
          %{display_hits: display_hits, element: element, ranged?: ranged?, coma?: coma?}
        )

      result = logical_skill_result([%{hit?: true, damage: damage}], target_state, coma?)
      maybe_apply_skill_knockback(attacker, target, skill_id, result, knockback_options)
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
          | {:ok,
             %{
               hit?: boolean(),
               damage: non_neg_integer(),
               target_survives?: boolean(),
               coma?: boolean()
             }}
          | {:error, atom()}
  def execute_acid_terror_attack(caster_state, target_id, opts) do
    execute_single_target_attack(
      caster_state,
      target_id,
      opts,
      &DamageCalculator.calculate_damage_ignoring_status_def/3,
      %{}
    )
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
      &Targeting.validate_enemy/2
    )
  end

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
         :ok <- authorize_target.(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}) do
      hit_opts = %{
        display_hits: display_hits,
        hit_rate_bonus_pct: hit_rate_bonus_pct,
        ignore_flee: Keyword.get(opts, :ignore_flee, false),
        ranged: ranged?,
        weapon_hit_metadata: weapon_hit_metadata
      }

      {results, coma_decision} =
        Enum.map_reduce(1..hits//1, :unchecked, fn _, decision ->
          apply_skill_damage(
            attacker,
            {target_type, target_pid, target},
            skill_id,
            skill_level,
            {calc_opts, damage_calculator},
            hit_opts,
            decision
          )
        end)

      result = logical_skill_result(results, target_state, coma_decision)
      maybe_apply_skill_knockback(attacker, target, skill_id, result, knockback_options(opts))

      if report_hit?, do: {:ok, reported_hit(results, result)}, else: :ok
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
    - `:skill_ratio` - percent of base attack the skill deals, or a one-arity
      function of the target's Chebyshev distance from `{x, y}` returning that
      percent, for a skill whose ratio falls off with distance (Magnum Break's
      inner and outer rings)
    - `:element` - optional attack-element override
    - `:skip_crit` - skip the critical roll
    - `:hit_rate_bonus_pct` - relative percent bonus applied to each target's
      already-clamped hit rate, as documented by `execute_skill_attack/3`
      (default `0`)
    - `:hit_count` - number of hits each connected target takes, each rolling
      its own hit/flee check and its own damage (default `1`); a target
      counts as hit if any of its hits connect
    - `:ranged` - forces `is_short: false` in each connected target's hit_info
      (default `false`, see `execute_skill_attack/3`)
    - `:typed_results` - returns connected `{unit_type, unit_id}` refs instead of
      bare ids from the same execution (default `false`)
    - `:target_skill_units` - additionally admits targetable enemy trap cells
      reached by the splash (default `false`)
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
        hits = Keyword.get(opts, :hit_count, 1)

        group
        |> SplashTargets.select_field(center, radius, attacker)
        |> hit_targets(
          attacker,
          skill_id,
          skill_level,
          calc_opts,
          hits,
          %{
            ranged?: Keyword.get(opts, :ranged, false),
            ignore_flee?: Keyword.get(opts, :ignore_flee, false),
            typed_results?: true,
            knockback_options: knockback_options(opts),
            hit_rate_bonus_pct: Keyword.get(opts, :hit_rate_bonus_pct, 0),
            display_hit_count: Keyword.get(opts, :display_hit_count)
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
    hits = Keyword.get(opts, :hit_count, 1)

    result_opts = %{
      ranged?: Keyword.get(opts, :ranged, false),
      ignore_flee?: Keyword.get(opts, :ignore_flee, false),
      typed_results?: Keyword.get(opts, :typed_results, false),
      knockback_options: knockback_options(opts),
      hit_rate_bonus_pct: Keyword.get(opts, :hit_rate_bonus_pct, 0),
      display_hit_count: Keyword.get(opts, :display_hit_count),
      splash_center: center
    }

    selection_opts = Keyword.take(opts, [:target_skill_units])

    attacker.map_name
    |> SplashTargets.select(center, radius, attacker, false, selection_opts)
    |> hit_targets(
      attacker,
      skill_id,
      skill_level,
      {calc_opts, damage_calculator},
      hits,
      result_opts
    )
  end

  @doc """
  Executes a line skill against the primary target plus every offensive
  target standing on the straight line of cells between the caster and it
  (inclusive of the target's own cell).

  Selects targets via `LineTargets.select/4`, then runs each through the
  shared single-target damage path **without** the per-target attack-range
  gate - the line already bounds the hit set. Each target rolls its own
  hit/flee check independently and resolves combined skill knockback once.
  Returns the list of connected target ids.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll
    - `:base_distance`, `:origin`, `:native_enabled`, `:native_target_types`, and
      `:native_requires_survival` - combined knockback options documented by
      `execute_skill_attack/3`
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
        |> hit_targets(attacker, skill_id, skill_level, calc_opts, 1, %{
          ranged?: false,
          ignore_flee?: false,
          typed_results?: false,
          knockback_options: knockback_options(opts),
          hit_rate_bonus_pct: Keyword.get(opts, :hit_rate_bonus_pct, 0)
        })

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
         hits,
         result_opts,
         authorize_target \\ fn _attacker, _target -> :ok end
       ) do
    Enum.flat_map(targets, fn {_unit_type, _target_id} = target_ref ->
      apply_splash_hits(
        attacker,
        target_ref,
        skill_id,
        skill_level,
        calc_opts,
        hits,
        result_opts,
        authorize_target
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
         %{
           ranged?: ranged?,
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
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}) do
      hit_opts = %{
        display_hits: Map.get(result_opts, :display_hit_count),
        hit_rate_bonus_pct: hit_rate_bonus_pct,
        ignore_flee: ignore_flee?,
        ranged: ranged?,
        weapon_hit_metadata: %{}
      }

      calc_opts = resolve_distance_ratio(calc_opts, result_opts, target_state)

      {results, coma_decision} =
        Enum.map_reduce(1..hits//1, :unchecked, fn _, decision ->
          apply_skill_damage(
            attacker,
            {target_type, target_pid, target},
            skill_id,
            skill_level,
            calc_opts,
            hit_opts,
            decision
          )
        end)

      result = logical_skill_result(results, target_state, coma_decision)
      maybe_apply_skill_knockback(attacker, target, skill_id, result, knockback_options)
      connected_target_result(result.hit?, target_ref, typed_results?)
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

  defp connected_target_result(false, _target_ref, _typed_results?), do: []
  defp connected_target_result(true, target_ref, true), do: [target_ref]
  defp connected_target_result(true, target_ref, false), do: [elem(target_ref, 1)]

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
    - `:base_distance`, `:origin`, `:native_enabled`, `:native_target_types`, and
      `:native_requires_survival` - combined knockback options documented by
      `execute_skill_attack/3`
  """
  @spec execute_misc_attack(struct(), integer() | Ref.t(), keyword()) :: :ok | {:error, atom()}
  def execute_misc_attack(caster_state, target_id, opts) do
    execute_misc_attack_with(caster_state, target_id, opts, &Targeting.validate_enemy/2)
  end

  @doc """
  Executes one misc hit owned by a supported player field.

  The exact group authorizes the target at delivery time; all misc calculation,
  hooks, packets, and settlement remain shared with `execute_misc_attack/3`.
  """
  @spec execute_field_misc_attack(struct(), Ref.t(), Group.t(), keyword()) ::
          :ok | {:error, atom()}
  def execute_field_misc_attack(caster_state, target_ref, %Group{} = group, opts) do
    with :ok <- validate_field_skill_opts(group, opts) do
      execute_misc_attack_with(
        caster_state,
        target_ref,
        opts,
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

    apply_misc_hit(
      attacker,
      target_ref,
      skill_id,
      skill_level,
      element,
      base_damage,
      1,
      %{
        authorize_target: authorize_target,
        ignore_element?: Keyword.get(opts, :ignore_element, false),
        owner_derived_trap?: false,
        knockback_options: knockback_options(opts)
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
               authorize_target: &Targeting.validate_enemy/2,
               ignore_element?: ignore_element?,
               owner_derived_trap?: target_skill_units?,
               knockback_options: knockback_options(opts)
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
  settlement behavior and returns after dispatching all eligible targets.
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
          display_hit_count!(opts),
          %{
            authorize_target: authorize_target,
            ignore_element?: Keyword.get(opts, :ignore_element, false),
            owner_derived_trap?: false,
            knockback_options: knockback_options(opts)
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
         :ok <- misc_opts.authorize_target.(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}),
         {:ok, %{damage: damage}} <-
           MiscDamageCalculator.calculate_misc_damage(
             attacker,
             target,
             misc_damage_opts(base_damage, element, misc_opts.ignore_element?)
           ) do
      coma? = decide_coma(:unchecked, attacker, target, damage) == true

      hit_info = %{
        dmg_type: :misc,
        is_short: false,
        element: element,
        skill_id: skill_id,
        skill_level: skill_level,
        coma?: coma?
      }

      source = damage_source(attacker, target_type)
      attack_flag = BattleFlags.build(:misc, :long, true)

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
          div: display_hits
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

      result = logical_skill_result([%{hit?: true, damage: damage}], target_state, coma?)

      maybe_apply_skill_knockback(
        attacker,
        target,
        skill_id,
        result,
        misc_opts.knockback_options
      )

      if delivery == :ok do
        dispatch_equip_autobonuses(attacker, target, attack_flag)
      end

      delivery
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
      display_hits: display_hits,
      hit_rate_bonus_pct: hit_rate_bonus_pct,
      ignore_flee: ignore_flee?,
      ranged: ranged?,
      knockback_options: knockback_options
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
               target: target,
               skill_id: skill_id,
               skill_level: skill_level,
               damage_result: damage_result,
               display_hits: display_hits,
               element: physical_attack_element(attacker, calc_opts),
               ranged: ranged?,
               coma?: decide_coma(:unchecked, attacker, target, damage_result.damage) == true,
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

  defp misc_damage_opts(base_damage, element, false),
    do: [base_damage: base_damage, element: element]

  defp misc_damage_opts(base_damage, element, true),
    do: [base_damage: base_damage, element: element, ignore_element: true]

  # Rolls the weapon-class hit/flee check, then applies damage on a connect or
  # broadcasts the miss/perfect-dodge packet otherwise. Returns the fragment
  # result while threading the target's logical coma decision.
  @spec apply_skill_damage(
          struct(),
          {:player | :mob | :homunculus | :skill_unit, pid(), struct()},
          integer(),
          pos_integer(),
          calc_context(),
          map(),
          coma_decision()
        ) :: {%{hit?: boolean(), damage: non_neg_integer()}, coma_decision()}
  defp apply_skill_damage(
         attacker,
         {target_type, _target_pid, target} = target_context,
         skill_id,
         skill_level,
         calc_context,
         hit_opts,
         coma_decision
       ) do
    if weapon_hit_intercepted?(
         attacker,
         target_type,
         target,
         Map.fetch!(hit_opts, :weapon_hit_metadata)
       ) do
      {%{hit?: false, damage: 0}, coma_decision}
    else
      resolve_skill_hit(
        attacker,
        target_context,
        skill_id,
        skill_level,
        calc_context,
        hit_opts,
        coma_decision
      )
    end
  end

  # A weapon-class skill hit passes through the target's `before_weapon_hit`
  # interception statuses (Guard) exactly as a basic attack does, but tagged
  # `basic_attack?: false` so basic-attack-only stances (Auto Counter, Blade
  # Stop) stay inert. An interception cancels this hit entirely: no hit roll and
  # no damage. A shield block (Guard) still broadcasts a zero-damage "guarded"
  # packet so the attacker sees the swing land for 0; other interceptions own
  # their own feedback effect and stay silent.
  # Magic and misc skills never call this path, so they can never be blocked.
  @spec weapon_hit_intercepted?(
          struct(),
          :player | :mob | :homunculus | :skill_unit,
          struct(),
          map()
        ) :: boolean()
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

        true

      {:intercept, _result} ->
        true

      :continue ->
        false
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
         hit_opts,
         coma_decision
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

        {%{hit?: false, damage: 0}, coma_decision}

      :perfect_dodge ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_perfect_dodge_packet(attacker, target)
        )

        {%{hit?: false, damage: 0}, coma_decision}

      :hit ->
        deliver_skill_hit(
          attacker,
          target_context,
          skill_id,
          skill_level,
          calc_context,
          hit_opts,
          coma_decision
        )
    end
  end

  defp deliver_skill_hit(
         attacker,
         {_target_type, _target_pid, target} = target_context,
         skill_id,
         skill_level,
         calc_context,
         hit_opts,
         coma_decision
       ) do
    %{display_hits: display_hits, ranged: ranged?} = hit_opts
    {calc_opts, damage_calculator} = damage_calculation(calc_context)
    element = physical_attack_element(attacker, calc_opts)

    case damage_calculator.(attacker, target, calc_opts) do
      {:ok, damage_result} ->
        coma_decision = decide_coma(coma_decision, attacker, target, damage_result.damage)

        damage =
          deliver_calculated_skill_hit(
            attacker,
            target_context,
            skill_id,
            skill_level,
            damage_result,
            %{
              display_hits: display_hits,
              element: element,
              ranged?: ranged?,
              coma?: coma_decision == true
            }
          )

        {%{hit?: true, damage: damage}, coma_decision}

      {:error, _reason} ->
        {%{hit?: false, damage: 0}, coma_decision}
    end
  end

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
    %{display_hits: display_hits, element: element, ranged?: ranged?, coma?: coma?} = hit_metadata

    hit_info = %{
      dmg_type: :physical,
      is_short: not ranged? and attacker.attack_range <= 3,
      element: element,
      skill_id: skill_id,
      skill_level: skill_level,
      coma?: coma?
    }

    source = damage_source(attacker, target_type)
    attack_flag = physical_skill_flag(hit_info)

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

    OnHitEffects.after_hit(attacker, target, damage_result,
      attack_flag: attack_flag,
      skill_id: skill_id
    )

    dispatch_equip_autocasts(attacker, target, target_pid, attack_flag)

    damage
  end

  # Rolls both sides' equipment autocasts for a landed skill hit: the caster's
  # own procs run in the caster's session, the target's when-hit procs in the
  # target's. Entries armed for normal swings only never match here.
  @spec dispatch_equip_autocasts(Combatant.t(), Combatant.t(), pid() | nil, BattleFlags.flag()) ::
          :ok
  defp dispatch_equip_autocasts(attacker, target, target_pid, attack_flag) do
    attacker
    |> EquipAutocast.on_attack(target, attack_flag)
    |> Enum.each(&send_auto_cast(self(), &1))

    target
    |> EquipAutocast.when_hit(attacker, attack_flag)
    |> Enum.each(&send_auto_cast(target_pid, &1))

    dispatch_equip_autobonuses(attacker, target, attack_flag)
  end

  defp dispatch_equip_autobonuses(attacker, target, attack_flag) do
    send_equip_autobonuses(
      attacker,
      EquipAutobonus.on_attack(attacker.equip_autobonuses, attack_flag)
    )

    send_equip_autobonuses(
      target,
      EquipAutobonus.when_hit(target.equip_autobonuses, attack_flag)
    )
  end

  defp send_equip_autobonuses(
         %{unit_type: :player, unit_id: unit_id, equip_autobonuses: registrations},
         [_ | _] = keys
       ) do
    with {:ok, pid} <- UnitRegistry.get_player_pid(unit_id) do
      Enum.each(keys, fn key ->
        source_identity = registrations |> Map.fetch!(key) |> Map.fetch!(:source_identity)
        GenServer.cast(pid, {:equip_autobonus_activate, key, source_identity})
      end)
    end

    :ok
  end

  defp send_equip_autobonuses(_combatant, _keys), do: :ok

  @spec send_auto_cast(pid(), EquipAutocast.proc()) :: :ok
  defp send_auto_cast(pid, {:auto_cast, skill_id, level, target}) do
    GenServer.cast(pid, {:skill, {:proc_cast, skill_id, level, target}})
  end

  # Classifies a physical skill hit for the trigger-flagged equipment bonuses:
  # a weapon attack of skill origin, melee or ranged as the delivered hit was.
  @spec physical_skill_flag(map()) :: BattleFlags.flag()
  defp physical_skill_flag(hit_info) do
    range = if Map.get(hit_info, :is_short, false), do: :short, else: :long
    BattleFlags.build(:weapon, range, true)
  end

  defp damage_calculation({calc_opts, damage_calculator}),
    do: {calc_opts, damage_calculator}

  defp damage_calculation(calc_opts),
    do: {calc_opts, &DamageCalculator.calculate_damage/3}

  defp physical_attack_element(attacker, calc_opts) do
    Keyword.get(calc_opts, :element) ||
      Map.get(
        ModifierCalculator.get_all_modifiers(attacker.unit_type, attacker.unit_id),
        :attack_element,
        attacker.weapon.element
      )
  end

  defp decide_coma(:unchecked, attacker, target, damage) when damage > 0,
    do: EquipComa.trigger?(attacker, target)

  defp decide_coma(decision, _attacker, _target, _damage), do: decision

  defp logical_skill_result(results, target_state, coma_decision) do
    damage = Enum.sum_by(results, & &1.damage)
    hit? = Enum.any?(results, & &1.hit?)
    coma? = coma_decision == true

    %{
      hit?: hit?,
      target_survives?:
        coma? or not hit? or damage == 0 or known_target_survives?(target_state, damage),
      coma?: coma?
    }
  end

  defp known_target_survives?(target_state, damage) do
    case target_hp(target_state) do
      hp when is_integer(hp) -> hp > damage
      nil -> false
    end
  end

  defp reported_hit(results, result),
    do: Map.put(result, :damage, Enum.sum_by(results, & &1.damage))

  defp maybe_apply_skill_knockback(attacker, target, skill_id, %{hit?: true} = result, opts) do
    _ = Knockback.skill(attacker, target, skill_id, result, opts)
    :ok
  end

  defp maybe_apply_skill_knockback(_attacker, _target, _skill_id, _result, _opts), do: :ok

  defp knockback_options(opts) do
    Keyword.take(opts, [
      :base_distance,
      :origin,
      :native_enabled,
      :native_target_types,
      :native_requires_survival
    ])
  end

  defp target_hp(%{stats: %{current_state: %{hp: hp}}}) when is_integer(hp), do: hp
  defp target_hp(%{hp: hp}) when is_integer(hp), do: hp
  defp target_hp(_target_state), do: nil

  # The cast skill's own accuracy bonus and the attacker's standing bonus stay
  # separate: they compound on the clamped hit rate rather than summing.
  defp hit_stats(attacker, hit_rate_bonus_pct) do
    %{
      hit: attacker.combat_stats.hit,
      char_id: attacker.unit_id,
      perfect_hit: EquipmentBonuses.perfect_hit_rate(attacker),
      skill_hit_rate_bonus_pct: hit_rate_bonus_pct,
      hit_rate_bonus_pct: Map.get(attacker.combat_stats, :hit_rate_bonus_pct, 0)
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
