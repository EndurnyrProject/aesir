defmodule Aesir.ZoneServer.Mmo.Combat.MagicAttack do
  @moduledoc """
  The magic damage paths: direct nukes, magic splashes, fixed-amount magic hits,
  ground skill-unit ticks, and the raw `deal_damage` entry used by status DoTs.

  Every path resolves its target through `TargetResolver`, broadcasts a
  `ZC_NOTIFY_SKILL` splash packet, and delivers the damage through
  `DamageApplication`.
  """

  require Logger

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Combat.EquipVanish
  alias Aesir.ZoneServer.Mmo.Combat.Hallucination
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @bolts %{
    14 => {:water, 100},
    19 => {:fire, 100},
    20 => {:wind, 100},
    90 => {:earth, 200}
  }

  @doc """
  Deals damage to a target entity (used by status effects).

  This is a simplified version of the attack paths that bypasses validation and
  is used by status effects and other systems. The hit carries
  `status_tick?: true`, so status absorb hooks that only shield against attacks
  (Basilica, pre-renewal Assumptio) let poison ticks and HP costs through.
  """
  @spec deal_damage(integer() | Ref.t(), integer(), atom(), atom()) :: :ok | {:error, atom()}
  def deal_damage(target, damage, element \\ :neutral, source_type \\ :status_effect) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target),
         :ok <- ensure_living_target(target_state, target_type),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         target_id <- target_combatant.unit_id do
      Logger.debug(
        "Combat: Dealing #{damage} #{element} damage to #{target_type} #{target_id} from #{source_type}"
      )

      apply_magic_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        Map.put(magic_hit_info(element, []), :status_tick?, true),
        nil
      )
    end
  end

  @doc """
  Applies an explicit damage amount as a single magic hit of the given element,
  bypassing MATK and MDEF.

  Intended for the Heal undead/demon branch: the already-computed heal value is
  delivered as holy damage, so MATK and MDEF play no role. The amount is raised to
  the magic minimum of 1 and then takes one attribute step, so an immune target
  takes 0. Resolves and range-checks the target
  identically to `execute_magic_attack/3`, broadcasts a `SkillDamage` packet, and
  applies the final damage.

  ## Options

    - `:skill_id` / `:skill_level` — identify the skill for the damage packet (required).
    - `:element` — attack element applied against the target's element resistance
      (default `:neutral`).
    - `:ignore_element` — deliver `amount` without the element table (Soul Siphon)
      (default `false`).
    - `:skip_range` — skip only the distance check (which gates on the caster's
      *weapon* attack range) for a cast whose skill range the interpreter already
      validated; map, life, and enemy-relation checks still run (default `false`).

  ## Returns

    - `{:ok, hit_ref}` on success.
    - `{:error, reason}` when the target is invalid, friendly, dead, or out of range.
  """
  @spec execute_magic_damage(struct(), integer() | Ref.t(), non_neg_integer(), keyword()) ::
          {:ok, Ref.t()} | {:error, atom()}
  def execute_magic_damage(caster_state, target_ref, amount, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    element = Keyword.get(opts, :element, :neutral)

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         target_id <- target.unit_id,
         :ok <- AttackValidator.validate(attacker, target, opts),
         :ok <- Targeting.validate_enemy(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}) do
      damage =
        if Keyword.get(opts, :ignore_element, false),
          do: max(amount, 1),
          else: DamageShared.apply_element_step(max(amount, 1), element, attacker, target)

      hit_info =
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        )

      case MagicDefense.resolve(target, hit_info) do
        :miss ->
          broadcast_magic_miss(attacker, target, skill_id, skill_level)
          {:ok, {target_type, target_id}}

        :reflect ->
          attacker
          |> deliver_reflected_hits(target, [damage], hit_info, {skill_id, skill_level}, 1)
          |> dispatch_reflected_procs()

          {:ok, {attacker.unit_type, attacker.unit_id}}

        :hit ->
          {target_type, target_pid, target_id, target_state, target}
          |> deliver_magic_hits([damage], hit_info, attacker, {skill_id, skill_level}, opts)
          |> magic_delivery_result({target_type, target_id})
      end
    end
  end

  @doc """
  Computes and applies a single magic skill-unit hit, broadcasting its visual.

  Used by magic ground skill-units (e.g. Storm Gust). Resolves the target
  combatant, runs the hit through `MagicDamageCalculator` (real MATK/MDEF/element)
  with the given `skill_ratio` and `element`, broadcasts a `ZC_NOTIFY_SKILL` from
  the target's cell so nearby players see the hit number, then applies the damage.

  ## Parameters
    - `caster` - the casting unit's combatant (`src_id`/MATK source)
    - `unit_type` / `target_id` - the target being hit
    - `skill_id` / `skill_level` - identify the skill for the damage packet
    - `element` - the skill's magic element (element resistance + damage context)
    - `skill_ratio` - percent of base MATK the skill deals this hit
    - `hit_divisions` - number of equal client-visible divisions for the one resolved hit.
      A negative value mirrors rAthena's negative `HitCount`: the total is
      floored to equal divisions before it is applied and sent as a positive
      client division count.
  """
  @spec apply_skill_unit_damage(
          struct(),
          atom(),
          integer(),
          integer(),
          integer(),
          atom(),
          non_neg_integer()
        ) :: :ok | {:error, atom()}
  @spec apply_skill_unit_damage(
          struct(),
          atom(),
          integer(),
          integer(),
          integer(),
          atom(),
          non_neg_integer(),
          pos_integer() | neg_integer()
        ) :: :ok | {:error, atom()}
  def apply_skill_unit_damage(
        caster,
        unit_type,
        target_id,
        skill_id,
        skill_level,
        element,
        skill_ratio
      ) do
    apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      skill_id,
      skill_level,
      element,
      skill_ratio,
      []
    )
  end

  def apply_skill_unit_damage(
        caster,
        unit_type,
        target_id,
        skill_id,
        skill_level,
        element,
        skill_ratio,
        hit_divisions
      )
      when is_integer(hit_divisions) do
    apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      skill_id,
      skill_level,
      element,
      skill_ratio,
      hit_divisions: hit_divisions
    )
  end

  @doc """
  Applies a magic ground-unit hit with optional multi-hit, flat-MATK, fixed
  damage, and target walk-delay traits.

  `:divide_hits_for_player?` mirrors Fire Pillar's caster rule in both modes: a
  player caster turns the positive division count negative, so the one computed
  total is quantized to whole divisions while the client receives the multi-hit
  animation. Non-player casters keep the positive count.

  `:damage_scale` (default `1`) multiplies the computed damage before delivery
  and re-clamps to a floor of 1.

  The canonical skill knockback options are `:base_distance`, `:origin`,
  `:native_enabled`, `:native_target_types`, and `:native_requires_survival`.
  Player-owned damaging ground hits also consume exact-skill equipment blow.

  `:delivery` (default `:unit`, see `t:Targeting.delivery/0`) says how the hit
  reached the target: a placed unit is the hit's actual source, so the target
  is re-checked with `Targeting.validate_delivery/4` before any calculation.
  A caster-timed hit that only reuses this path (Water Ball, Ruwach) passes
  `:direct`.

  `:additional_effect` (see `t:additional_effect/0`) runs the skill's on-hit
  effect, after the damage and before any knockback, only for a hit that
  connected: a settled amount of at least 1 (or one forwarded by Devotion),
  not cancelled by Magic Rod, on a target that survives it.

  `:report_hit` (default `false`) returns `{:ok, %{hit?: boolean()}}` instead of
  `:ok`, where `hit?` says the hit dealt damage (a settled amount above 0, or
  one forwarded by Devotion).
  """
  @spec apply_skill_unit_damage(
          struct(),
          atom(),
          integer(),
          integer(),
          integer(),
          atom(),
          non_neg_integer(),
          keyword()
        ) :: :ok | {:ok, %{hit?: boolean()}} | {:error, atom()}
  def apply_skill_unit_damage(
        caster,
        unit_type,
        target_id,
        skill_id,
        skill_level,
        element,
        skill_ratio,
        opts
      )
      when is_list(opts) do
    hit_divisions = Keyword.get(opts, :hit_divisions, 1)
    bonus_matk = Keyword.get(opts, :bonus_matk, 0)
    fixed_damage = Keyword.get(opts, :fixed_damage)

    hit_divisions =
      if caster.unit_type == :player and Keyword.get(opts, :divide_hits_for_player?, false),
        do: -abs(hit_divisions),
        else: hit_divisions

    with {:ok, prepared} <-
           prepare_skill_unit_hit(
             caster,
             {unit_type, target_id},
             skill_id,
             Keyword.get(opts, :delivery, :unit)
           ) do
      damage =
        skill_unit_damage(
          caster,
          prepared.target,
          element,
          skill_ratio,
          bonus_matk,
          skill_id,
          fixed_damage
        )

      damage = scale_damage(damage, Keyword.get(opts, :damage_scale, 1))

      {damage, packet_divisions} =
        DamageShared.normalize_damage_divisions(damage, hit_divisions)

      deliver_skill_unit_hit(
        prepared,
        damage,
        Keyword.merge(opts,
          skill_level: skill_level,
          element: element,
          packet_divisions: packet_divisions
        )
      )
    end
  end

  @typedoc """
  A skill's on-hit effect: called with the hit's effective source (the reflector
  when the spell was reflected) and the ref of the unit it hit.
  """
  @type additional_effect :: (struct(), Ref.t() -> term())

  @typedoc "A resolved ground target consumed synchronously by its preparing callback."
  @type prepared_ground_hit :: %{
          caster: struct(),
          target: struct(),
          target_state: struct(),
          target_pid: pid(),
          target_type: atom(),
          target_id: integer(),
          position: {integer(), integer(), String.t()},
          skill_id: integer()
        }

  @doc """
  Resolves and validates a ground target without rolling damage or delivering effects.

  `delivery` (default `:unit`) re-checks the target as `apply_skill_unit_damage/8`
  documents.
  """
  @spec prepare_skill_unit_hit(struct(), Ref.t(), integer(), Targeting.delivery()) ::
          {:ok, prepared_ground_hit()} | {:error, atom()}
  def prepare_skill_unit_hit(caster, {unit_type, target_id}, skill_id, delivery \\ :unit) do
    with {:ok, target_pid, target_state, target_type} <-
           resolve_skill_unit_target(unit_type, target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         :ok <- ensure_living_target(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Rules.validate_target(caster, target, %{skill_id: skill_id}),
         :ok <- Targeting.validate_delivery(caster, target, skill_id, delivery),
         {:ok, position} <- SpatialIndex.get_unit_position(unit_type, target_id) do
      {:ok,
       %{
         caster: caster,
         target: target,
         target_state: target_state,
         target_pid: target_pid,
         target_type: target_type,
         target_id: target_id,
         position: position,
         skill_id: skill_id
       }}
    end
  end

  @doc """
  Delivers a calculated ground hit through recipient hooks, packets and owner mutation.

  Consume the prepared target immediately in the same callback. The nonnegative
  amount is already formula-complete: element, defense, scaling and hit division
  are not recalculated. Element and level options describe the hit to its recipients.
  `:additional_effect` and `:report_hit` behave as `apply_skill_unit_damage/8`
  documents.
  """
  @spec deliver_skill_unit_hit(prepared_ground_hit(), non_neg_integer(), keyword()) ::
          :ok | {:ok, %{hit?: boolean()}}
  def deliver_skill_unit_hit(
        %{
          caster: caster,
          target: target,
          target_state: target_state,
          target_pid: target_pid,
          target_type: target_type,
          target_id: target_id,
          position: {tx, ty, map_name},
          skill_id: skill_id
        },
        damage,
        opts
      )
      when is_integer(damage) and damage >= 0 do
    skill_level = Keyword.fetch!(opts, :skill_level)
    element = Keyword.fetch!(opts, :element)
    packet_divisions = Keyword.get(opts, :packet_divisions, 1)
    dst_delay = Keyword.get(opts, :dst_delay, 0)
    coma_decision = decide_coma(caster, target, [damage])

    hit_info =
      element
      |> magic_hit_info(
        skill_id: skill_id,
        skill_level: skill_level,
        from_caster?: false,
        coma?: coma_decision == true
      )
      |> Map.put(
        :proc,
        EquipProcDispatch.spec(caster, target, target_state, magic_attack_flag(),
          divisions: packet_divisions,
          skill_id: skill_id,
          immediate?: EquipProcDispatch.immediate?(skill_id, Keyword.get(opts, :delivery, :unit))
        )
      )

    {damage, hit_info} =
      prepare_magic_hit(
        target_type,
        target_id,
        damage,
        hit_info,
        damage_source(caster, target_type)
      )

    packet =
      PacketFactory.build_splash_damage_packet(
        caster.unit_id,
        target_id,
        skill_id,
        skill_level,
        damage,
        div: packet_divisions,
        dst_delay: dst_delay
      )

    packet = Hallucination.maybe_garble(packet, target_type)
    Broadcast.to_in_range(map_name, tx, ty, Config.view_range(), packet)
    delivery = apply_magic_damage(target_type, target_pid, target_id, damage, hit_info, caster)

    if delivery == :ok do
      run_additional_effect(
        Keyword.get(opts, :additional_effect),
        caster,
        {target_type, target_id},
        target_state,
        damage,
        hit_info,
        coma_decision == true
      )
    end

    if dst_delay > 0 do
      apply_walk_delay(target_type, target_pid, dst_delay)
    end

    result = magic_result(target_state, [damage], coma_decision)

    maybe_apply_magic_knockback(
      delivery,
      caster,
      target,
      target_type,
      skill_id,
      result,
      opts
    )

    EquipProcDispatch.dispatch_delivered(delivery, hit_info, damage)

    if Keyword.get(opts, :report_hit, false),
      do: {:ok, %{hit?: damage > 0 or hit_info[:devotion_rerouted?] == true}},
      else: :ok
  end

  @doc """
  Executes one of the four canonical bolt skills without entering a player cast path.

  The selected bolt id is the damage and packet skill id. Canonical element and
  divisions cannot be overridden; callers may override the default per-hit ratio
  for effects attached to the selected bolt. Returns the ref of the unit hit.
  """
  @spec execute_bolt(struct(), integer() | Ref.t(), integer(), pos_integer(), keyword()) ::
          {:ok, Ref.t()} | {:error, atom()}
  def execute_bolt(caster, target_ref, bolt_id, level, opts \\ [])

  def execute_bolt(caster, target_ref, bolt_id, level, opts)
      when is_integer(level) and level > 0 and is_list(opts) do
    case Map.fetch(@bolts, bolt_id) do
      {:ok, {element, default_ratio}} ->
        bolt_opts =
          Keyword.merge(opts,
            skill_id: bolt_id,
            skill_level: level,
            skill_ratio: Keyword.get(opts, :skill_ratio, default_ratio),
            hit_divisions: level,
            element: element,
            skip_range: true
          )

        Combat.execute_magic_attack(caster, target_ref, bolt_opts)

      :error ->
        {:error, :invalid_bolt}
    end
  end

  def execute_bolt(_caster, _target_ref, _bolt_id, _level, _opts), do: {:error, :invalid_level}

  @doc """
  Executes a direct single-target magic skill from a caster against a target.

  Mirrors `execute_skill_attack/3` but runs the magic pipeline: it resolves and
  range-checks the target, runs `MagicDamageCalculator.calculate_magic_damage/3`
  once, normalizes the signed hit divisions, broadcasts one `ZC_NOTIFY_SKILL`
  packet and applies the logical total through the shared unit-damage
  path. Used by direct nukes (bolts, Soul Strike, Frost Diver).

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base MATK each hit deals (default `100`)
    - `:bonus_matk` - flat MATK added after the skill-ratio step (default `0`)
    - `:element` - the skill's magic element (default `:neutral`)
    - `:hit_divisions` - signed divisions of one calculated attack (default `1`);
      the packet shows the normalized count
    - `:skip_range` - skip only the distance check, which gates on the caster's
      *weapon* attack range. Direct nukes must pass it: their skill range is
      validated by the interpreter at cast start and castend, and the weapon-range
      gate would fizzle any cast beyond melee reach. Map, life, and enemy-relation
      checks still run (default `false`)

  ## Returns
    - `{:ok, hit_ref}` if the skill connected
    - `{:error, reason}` if the target was invalid, friendly, dead, or out of range
  """
  @spec execute_magic_attack(struct(), integer() | Ref.t(), keyword()) ::
          {:ok, Ref.t()} | {:error, atom()}
  def execute_magic_attack(caster_state, target_ref, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    bonus_matk = Keyword.get(opts, :bonus_matk, 0)
    element = Keyword.get(opts, :element, :neutral)
    hit_divisions = Keyword.get(opts, :hit_divisions, 1)

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         target_id <- target.unit_id,
         :ok <- AttackValidator.validate(attacker, target, opts),
         :ok <- Targeting.validate_enemy(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}) do
      {:ok, %{damage: damage}} =
        MagicDamageCalculator.calculate_magic_damage(attacker, target,
          element: element,
          skill_ratio: skill_ratio,
          bonus_matk: bonus_matk,
          skill_id: skill_id,
          ignore_mdef: Keyword.get(opts, :ignore_mdef, false)
        )

      {damage, packet_divisions} =
        DamageShared.normalize_damage_divisions(damage, hit_divisions)

      damages = [damage]
      opts = Keyword.put(opts, :packet_divisions, packet_divisions)

      hit_info =
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        )

      case MagicDefense.resolve(target, hit_info) do
        :miss ->
          broadcast_magic_miss(attacker, target, skill_id, skill_level)
          {:ok, {target_type, target_id}}

        :reflect ->
          attacker
          |> deliver_reflected_hits(
            target,
            damages,
            hit_info,
            {skill_id, skill_level},
            packet_divisions
          )
          |> dispatch_reflected_procs()

          {:ok, {attacker.unit_type, attacker.unit_id}}

        :hit ->
          {target_type, target_pid, target_id, target_state, target}
          |> deliver_magic_hits(damages, hit_info, attacker, {skill_id, skill_level}, opts)
          |> magic_delivery_result({target_type, target_id})
      end
    end
  end

  @doc """
  Executes a center+radius magic splash against every offensive target in range.

  Selects the hit set once per event and runs each target through
  `MagicDamageCalculator` once before normalizing divisions. Broadcasts one
  `ZC_NOTIFY_SKILL` packet per target and applies the logical damage.
  With `:split` the total damage is divided evenly across the number of targets
  hit (Napalm Beat); without it each target takes the full per-target damage.
  Returns one typed `{unit_type, unit_id}` reference per affected target.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base MATK each target takes (default `100`), or a
      one-arity function of the target's Chebyshev distance from `center`
      returning that percent, for a blast whose ratio falls off with distance
      (Fire Ball's outer ring)
    - `:element` - the skill's magic element (default `:neutral`)
    - `:split` - divide total damage by the number of targets hit (default `false`)
    - `:line_of_sight` - require an unobstructed projectile path (default `false`)
    - `:hit_divisions` - signed divisions of each target's one attack (default `1`)
    - `:delivery` - how the splash reached each target (`t:Targeting.delivery/0`,
      default `:direct`); a target refused by `Targeting.validate_delivery/4` is
      neither calculated nor struck, but still counts toward `:split`
    - `:target_filter` - a one-arity predicate on each selected `{unit_type,
      unit_id}`; a rejected unit is not struck and does not count toward `:split`
    - `:additional_effect` - the skill's on-hit effect (`t:additional_effect/0`),
      run per connected hit as `apply_skill_unit_damage/8` documents; a
      reflected hit runs it on the caster with the reflector as its source
  """
  @spec execute_magic_splash(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [{atom(), integer()}]
  def execute_magic_splash(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    element = Keyword.get(opts, :element, :neutral)
    split = Keyword.get(opts, :split, false)
    line_of_sight = Keyword.get(opts, :line_of_sight, false)
    hit_divisions = Keyword.get(opts, :hit_divisions, 1)

    targets =
      attacker.map_name
      |> SplashTargets.select(center, radius, attacker)
      |> filter_splash_line_of_sight(attacker.map_name, center, line_of_sight)
      |> Enum.filter(Keyword.get(opts, :target_filter, fn _ref -> true end))

    divisor = if split, do: max(length(targets), 1), else: 1

    {hits, results} =
      Enum.flat_map_reduce(targets, %{}, fn target_ref, results ->
        {hits, _decision, result} =
          apply_magic_splash_hit(
            attacker,
            target_ref,
            skill_id,
            skill_level,
            %{
              element: element,
              skill_ratio: skill_ratio,
              divisor: divisor,
              center: center,
              hit_divisions: hit_divisions,
              delivery: Keyword.get(opts, :delivery, :direct),
              additional_effect: Keyword.get(opts, :additional_effect),
              caster_state: caster_state
            },
            :unchecked
          )

        {hits, merge_magic_splash_result(results, result)}
      end)

    hits
    |> Enum.uniq()
    |> Enum.each(fn target_ref ->
      result = Map.fetch!(results, target_ref)

      maybe_apply_magic_knockback(
        result.delivery,
        attacker,
        result.target,
        result.target_type,
        skill_id,
        magic_result(result.target_state, result.damages, result.coma_decision),
        opts
      )
    end)

    hits
  end

  # A blast whose per-level ratio depends on how far the victim stands from the
  # centre (Fire Ball's outer ring) passes `:skill_ratio` as a one-arity function
  # of that Chebyshev distance, the same shape the physical splash path takes.
  # Every other caller passes a plain percent, which falls through untouched.
  @spec distance_ratio(
          number() | (non_neg_integer() -> number()),
          {integer(), integer()},
          struct()
        ) ::
          number()
  defp distance_ratio(ratio_fun, {cx, cy}, target_state) when is_function(ratio_fun, 1),
    do: ratio_fun.(Geometry.chebyshev_distance(cx, cy, target_state.x, target_state.y))

  defp distance_ratio(skill_ratio, _center, _target_state), do: skill_ratio

  # A scale of 1 preserves the computed amount; other factors retain the hit floor.
  defp scale_damage(damage, 1), do: damage
  defp scale_damage(damage, scale), do: max(1, trunc(damage * scale))

  defp skill_unit_damage(
         attacker,
         target,
         element,
         skill_ratio,
         bonus_matk,
         skill_id,
         nil
       ) do
    {:ok, %{damage: damage}} =
      MagicDamageCalculator.calculate_magic_damage(attacker, target,
        element: element,
        skill_ratio: skill_ratio,
        bonus_matk: bonus_matk,
        skill_id: skill_id
      )

    damage
  end

  defp skill_unit_damage(
         attacker,
         target,
         element,
         _skill_ratio,
         _bonus_matk,
         _skill_id,
         fixed_damage
       )
       when is_integer(fixed_damage) and fixed_damage >= 0 do
    DamageShared.apply_element_step(max(fixed_damage, 1), element, attacker, target)
  end

  defp apply_magic_damage(:skill_unit, manager_pid, target_id, damage, _hit_info, attacker) do
    source = if attacker, do: {attacker.unit_type, attacker.unit_id}
    DamageApplication.damage_skill_unit(manager_pid, target_id, damage, source)
  end

  defp apply_magic_damage(target_type, target_pid, target_id, damage, hit_info, attacker) do
    attacker_ref = if attacker, do: damage_source(attacker, target_type)

    DamageApplication.apply_unit_damage(
      target_type,
      target_pid,
      target_id,
      damage,
      hit_info,
      attacker_ref
    )

    :ok
  end

  defp apply_walk_delay(unit_type, target_pid, dst_delay) when unit_type in [:player, :mob],
    do: DamageApplication.unit_session(unit_type).apply_walk_delay(target_pid, dst_delay)

  defp apply_walk_delay(:homunculus, _target_pid, _dst_delay), do: :ok

  defp magic_result(target_state, damages, coma_decision) do
    final_damage = damages |> Enum.filter(&(&1 > 0)) |> Enum.sum()
    hit? = final_damage > 0
    coma? = hit? and coma_decision == true

    %{
      hit?: hit?,
      target_survives?: coma? or not hit? or known_target_survives?(target_state, final_damage),
      coma?: coma?
    }
  end

  defp maybe_apply_magic_knockback(
         :ok,
         attacker,
         target,
         target_type,
         skill_id,
         %{hit?: true} = result,
         opts
       )
       when target_type != :skill_unit do
    _ = Knockback.skill(attacker, target, skill_id, result, knockback_options(opts))
    :ok
  end

  defp maybe_apply_magic_knockback(
         {:local_effects, _effects},
         attacker,
         target,
         target_type,
         skill_id,
         result,
         opts
       ) do
    maybe_apply_magic_knockback(:ok, attacker, target, target_type, skill_id, result, opts)
  end

  defp maybe_apply_magic_knockback(
         _delivery,
         _attacker,
         _target,
         _target_type,
         _skill_id,
         _result,
         _opts
       ),
       do: :ok

  defp knockback_options(opts) do
    Keyword.take(opts, [
      :base_distance,
      :origin,
      :native_enabled,
      :native_target_types,
      :native_requires_survival
    ])
  end

  # rAthena's `skill_additional_effect` runs only when the hit reached ATK_DEF
  # (its settled total is at least 1; a Devotion-forwarded hit still connected)
  # and the recipient is alive after the damage. A skill-unit cell has no
  # status data, so nothing applies to it.
  defp run_additional_effect(nil, _source, _ref, _state, _damage, _hit_info, _coma?), do: :ok

  defp run_additional_effect(_fun, _source, {:skill_unit, _id}, _state, _dmg, _info, _coma?),
    do: :ok

  defp run_additional_effect(fun, source, ref, target_state, damage, hit_info, coma?) do
    if additional_effect?(target_state, damage, hit_info, coma?), do: fun.(source, ref)
    :ok
  end

  # A reflected spell's on-hit effect lands on the caster, sourced from the reflector.
  defp run_reflected_effect(
         {settled, settled_info} = reflected_hit,
         splash,
         reflector,
         caster_ref
       ) do
    run_additional_effect(
      splash.additional_effect,
      reflector,
      caster_ref,
      splash.caster_state,
      settled,
      settled_info,
      false
    )

    reflected_hit
  end

  defp additional_effect?(_state, _damage, %{magic_rod_miss?: true}, _coma?), do: false
  defp additional_effect?(_state, _damage, %{devotion_rerouted?: true}, _coma?), do: true

  defp additional_effect?(target_state, damage, _hit_info, coma?),
    do: damage > 0 and (coma? or known_target_survives?(target_state, damage))

  defp known_target_survives?(target_state, damage) do
    case target_hp(target_state) do
      hp when is_integer(hp) -> hp > damage
      nil -> false
    end
  end

  defp target_hp(%{stats: %{current_state: %{hp: hp}}}) when is_integer(hp), do: hp
  defp target_hp(%{hp: hp}) when is_integer(hp), do: hp
  defp target_hp(_target_state), do: nil

  defp ensure_living_target(_target_state, :skill_unit), do: :ok

  defp ensure_living_target(target_state, _target_type) do
    if Unit.living?(target_state), do: :ok, else: {:error, :target_dead}
  end

  defp resolve_skill_unit_target(unit_type, target_id) do
    case TargetResolver.resolve(unit_type, target_id) do
      {:error, :not_found} -> {:error, :target_not_found}
      result -> result
    end
  end

  # The hit's skill and origin are retained through preparation. A direct cast,
  # including its splash, originates at the caster; a placed skill unit or status
  # tick does not. Unknown origins remain false so they cannot be intercepted.
  defp magic_hit_info(element, opts) do
    %{
      dmg_type: :magic,
      is_short: false,
      element: element,
      skill_id: Keyword.get(opts, :skill_id),
      skill_level: Keyword.get(opts, :skill_level),
      from_caster?: Keyword.get(opts, :from_caster?, false),
      reflected: Keyword.get(opts, :reflected, false),
      coma?: Keyword.get(opts, :coma?, false)
    }
  end

  defp broadcast_magic_miss(attacker, target, skill_id, skill_level) do
    packet =
      PacketFactory.build_splash_damage_packet(
        attacker.unit_id,
        target.unit_id,
        skill_id,
        skill_level,
        0,
        div: 1,
        missed: true
      )

    DamageApplication.broadcast_nearby(target, packet)
  end

  defp apply_and_broadcast_magic_damage(
         :skill_unit,
         target_pid,
         target_id,
         damage,
         hit_info,
         attacker,
         target,
         packet
       ) do
    with :ok <- apply_magic_damage(:skill_unit, target_pid, target_id, damage, hit_info, attacker) do
      {tx, ty} = target.position
      packet = Hallucination.maybe_garble(packet, :skill_unit)
      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)
    end
  end

  defp apply_and_broadcast_magic_damage(
         target_type,
         target_pid,
         target_id,
         damage,
         hit_info,
         attacker,
         target,
         packet
       ) do
    {tx, ty} = target.position
    packet = Hallucination.maybe_garble(packet, target_type)
    Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)
    apply_magic_damage(target_type, target_pid, target_id, damage, hit_info, attacker)
  end

  defp filter_splash_line_of_sight(targets, _map_name, _center, false), do: targets

  defp filter_splash_line_of_sight(targets, map_name, center, true) do
    Enum.filter(targets, &splash_target_visible?(map_name, center, &1))
  end

  defp splash_target_visible?(map_name, center, {unit_type, target_id}) do
    case TargetResolver.resolve(unit_type, target_id) do
      {:ok, _pid, target_state, _target_type} ->
        target = target_state.__struct__.to_combatant(target_state)
        LineOfSight.clear?(map_name, center, target.position)

      _ ->
        false
    end
  end

  defp apply_magic_splash_hit(
         attacker,
         {unit_type, target_id} = target_ref,
         skill_id,
         skill_level,
         %{
           element: element,
           skill_ratio: skill_ratio,
           divisor: divisor,
           center: center,
           hit_divisions: hit_divisions
         } = splash,
         coma_decision
       ) do
    with {:ok, target_pid, target_state, target_type} <-
           TargetResolver.resolve(unit_type, target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Targeting.validate_enemy(attacker, target),
         :ok <- Rules.validate_target(attacker, target, %{skill_id: skill_id}),
         :ok <-
           Targeting.validate_delivery(
             attacker,
             target,
             skill_id,
             Map.get(splash, :delivery, :direct)
           ),
         {:ok, %{damage: damage}} <-
           MagicDamageCalculator.calculate_magic_damage(attacker, target,
             element: element,
             skill_ratio: distance_ratio(skill_ratio, center, target_state),
             skill_id: skill_id,
             matk_divisor: divisor
           ) do
      {damage, packet_divisions} =
        DamageShared.normalize_damage_divisions(damage, hit_divisions)

      hit_info =
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        )

      case MagicDefense.resolve(target, hit_info) do
        :miss ->
          broadcast_magic_miss(attacker, target, skill_id, skill_level)

          result = %{
            target_ref: target_ref,
            target_state: target_state,
            target: target,
            target_type: target_type,
            damage: 0,
            coma_decision: coma_decision,
            delivery: :miss
          }

          {[target_ref], coma_decision, result}

        :reflect ->
          caster_ref = {attacker.unit_type, attacker.unit_id}

          attacker
          |> deliver_reflected_hits(
            target,
            [damage],
            hit_info,
            {skill_id, skill_level},
            packet_divisions
          )
          |> Enum.map(&run_reflected_effect(&1, splash, target, caster_ref))
          |> dispatch_reflected_procs()

          result = %{
            target_ref: caster_ref,
            target_state: nil,
            target: attacker,
            target_type: attacker.unit_type,
            damage: damage,
            coma_decision: coma_decision,
            delivery: :reflect
          }

          {[caster_ref], coma_decision, result}

        :hit ->
          deliver_magic_splash_hit(
            {target_ref, target_pid, target_state, target_type, target},
            attacker,
            damage,
            hit_info,
            {skill_id, skill_level},
            coma_decision,
            {packet_divisions, splash.additional_effect, Map.get(splash, :delivery, :direct)}
          )
      end
    else
      _ -> {[], coma_decision, nil}
    end
  end

  defp deliver_magic_splash_hit(
         {target_ref, target_pid, target_state, target_type, target},
         attacker,
         damage,
         hit_info,
         {skill_id, skill_level},
         coma_decision,
         {packet_divisions, additional_effect, delivery}
       ) do
    target_id = target.unit_id
    {tx, ty} = target.position
    coma_decision = decide_coma_once(coma_decision, attacker, target, damage)
    source = damage_source(attacker, target_type)

    hit_info =
      hit_info
      |> Map.put(:coma?, coma_decision == true)
      |> Map.put(
        :proc,
        EquipProcDispatch.spec(attacker, target, target_state, magic_attack_flag(),
          divisions: packet_divisions,
          skill_id: skill_id,
          immediate?: EquipProcDispatch.immediate?(skill_id, delivery)
        )
      )

    {damage, hit_info} =
      prepare_magic_hit(target_type, target_id, damage, hit_info, source)

    hit_info =
      if hit_info[:magic_rod_miss?], do: Map.put(hit_info, :coma?, false), else: hit_info

    if damage > 1, do: EquipVanish.after_hit(attacker, target, target_pid, magic_attack_flag())

    packet =
      PacketFactory.build_splash_damage_packet(
        attacker.unit_id,
        target_id,
        skill_id,
        skill_level,
        damage,
        div: packet_divisions,
        missed: hit_info[:magic_rod_miss?] == true
      )

    packet = Hallucination.maybe_garble(packet, target_type)
    Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)

    delivery =
      DamageApplication.apply_unit_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        hit_info,
        source
      )

    if delivery == :ok or match?({:local_effects, _effects}, delivery) do
      run_additional_effect(
        additional_effect,
        attacker,
        target_ref,
        target_state,
        damage,
        hit_info,
        hit_info[:coma?] == true
      )
    end

    EquipProcDispatch.dispatch_delivered(delivery, hit_info, damage)

    result = %{
      target_ref: target_ref,
      target_state: target_state,
      target: target,
      target_type: target_type,
      damage: damage,
      coma_decision: coma_decision,
      delivery: delivery
    }

    {[target_ref], coma_decision, result}
  end

  defp merge_magic_splash_result(results, nil), do: results

  defp merge_magic_splash_result(results, result) do
    initial = result |> Map.put(:damages, [result.damage]) |> Map.delete(:damage)

    Map.update(results, result.target_ref, initial, fn existing ->
      %{
        existing
        | target: result.target,
          damages: [result.damage | existing.damages],
          coma_decision: result.coma_decision,
          delivery: successful_delivery(existing.delivery, result.delivery)
      }
    end)
  end

  defp magic_delivery_result(:ok, target_ref), do: {:ok, target_ref}
  defp magic_delivery_result(delivery, _target_ref), do: delivery

  defp successful_delivery(:ok, _delivery), do: :ok
  defp successful_delivery(_delivery, :ok), do: :ok
  defp successful_delivery({:local_effects, _effects} = delivery, _current), do: delivery
  defp successful_delivery(_previous, {:local_effects, _effects} = delivery), do: delivery
  defp successful_delivery(_previous, delivery), do: delivery

  # Delivers a reflected hit to the caster's owning session. Unlike an ordinary
  # hit this never assumes the current process owns the caster: a Sight Blaster
  # tick runs in the status tick manager and a Homunculus bolt runs in its
  # owner's session, so the owner pid is resolved from the registry and the
  # damage is always queued rather than returned as aggregate-local effects.
  # Returns each reflected hit's settled amount and prepared hit information.
  defp deliver_reflected_hits(
         attacker,
         reflector,
         damages,
         hit_info,
         {skill_id, skill_level},
         divisions
       ) do
    attacker_modifiers = DamageShared.attacker_modifiers(attacker)
    hit_info = Map.put(hit_info, :reflected, true)
    source = damage_source(reflector, attacker.unit_type)

    prepared_hits =
      Enum.map(damages, fn damage ->
        damage
        |> DamageShared.apply_element_step(hit_info.element, attacker, attacker,
          attacker_modifiers: attacker_modifiers
        )
        |> then(&prepare_magic_hit(attacker.unit_type, attacker.unit_id, &1, hit_info, source))
      end)

    Enum.map(prepared_hits, fn {damage, prepared_hit_info} ->
      packet =
        PacketFactory.build_splash_damage_packet(
          reflector.unit_id,
          attacker.unit_id,
          skill_id,
          skill_level,
          damage,
          div: divisions,
          missed: prepared_hit_info[:magic_rod_miss?] == true
        )

      DamageApplication.broadcast_nearby(attacker, packet)

      proc_opts = [
        divisions: divisions,
        skill_id: skill_id,
        immediate?: EquipProcDispatch.immediate?(skill_id, :direct)
      ]

      {damage,
       queue_reflected_damage(attacker, damage, prepared_hit_info, source, {reflector, proc_opts})}
    end)
  end

  # The reflector's side of each reflected hit, after the hit's effects.
  defp dispatch_reflected_procs(reflected_hits) do
    Enum.each(reflected_hits, fn {damage, hit_info} ->
      EquipProcDispatch.dispatch_hit(hit_info, damage)
    end)
  end

  # The reflector is the hit's attacker for equipment procs and the caster its
  # target. Returns the hit information carrying that `:proc` spec, so the
  # reflector's side is dispatched after the hit's effects; a caster that is
  # gone returns it without one.
  defp queue_reflected_damage(
         %{unit_type: :homunculus, unit_id: unit_id} = caster,
         damage,
         hit_info,
         source,
         {reflector, proc_opts}
       ) do
    case UnitRegistry.get_unit(:homunculus, unit_id) do
      {:ok, {_module, state, owner_pid}} ->
        effect =
          DamageApplication.local_damage_effect({:homunculus, unit_id}, damage, hit_info, source)

        GenServer.cast(owner_pid, effect)
        proc = EquipProcDispatch.spec(reflector, caster, state, magic_attack_flag(), proc_opts)
        Map.put(hit_info, :proc, proc)

      {:error, _reason} ->
        hit_info
    end
  end

  defp queue_reflected_damage(
         %{unit_type: unit_type, unit_id: unit_id} = caster,
         damage,
         hit_info,
         source,
         {reflector, proc_opts}
       ) do
    case TargetResolver.resolve(unit_type, unit_id) do
      {:ok, owner_pid, state, ^unit_type} ->
        proc = EquipProcDispatch.spec(reflector, caster, state, magic_attack_flag(), proc_opts)
        hit_info = Map.put(hit_info, :proc, proc)

        DamageApplication.apply_unit_damage(
          unit_type,
          owner_pid,
          unit_id,
          damage,
          hit_info,
          source
        )

        hit_info

      _gone ->
        hit_info
    end
  end

  defp deliver_magic_hits(
         {target_type, target_pid, target_id, target_state, target},
         damages,
         hit_info,
         attacker,
         {skill_id, skill_level},
         opts
       ) do
    source = damage_source(attacker, target_type)
    coma_decision = decide_coma(attacker, target, damages)

    hit_info =
      hit_info
      |> Map.put(:coma?, coma_decision == true)
      |> Map.put(
        :proc,
        EquipProcDispatch.spec(attacker, target, target_state, magic_attack_flag(),
          divisions: Keyword.get(opts, :packet_divisions, 1),
          skill_id: skill_id,
          immediate?:
            EquipProcDispatch.immediate?(skill_id, Keyword.get(opts, :delivery, :direct))
        )
      )

    [{damage, prepared_hit_info}] =
      Enum.map(damages, &prepare_magic_hit(target_type, target_id, &1, hit_info, source))

    prepared_hit_info =
      if prepared_hit_info[:magic_rod_miss?],
        do: Map.put(prepared_hit_info, :coma?, false),
        else: prepared_hit_info

    apply_vanish_hits(attacker, target, target_pid, [damage])

    packet =
      PacketFactory.build_splash_damage_packet(
        attacker.unit_id,
        target_id,
        skill_id,
        skill_level,
        damage,
        div: Keyword.get(opts, :packet_divisions, 1),
        missed: prepared_hit_info[:magic_rod_miss?] == true
      )

    delivery =
      apply_and_broadcast_magic_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        prepared_hit_info,
        attacker,
        target,
        packet
      )

    final_damages = [damage]

    maybe_apply_magic_knockback(
      delivery,
      attacker,
      target,
      target_type,
      skill_id,
      magic_result(target_state, final_damages, coma_decision),
      opts
    )

    EquipProcDispatch.dispatch_delivered(delivery, prepared_hit_info, damage)
    delivery
  end

  defp apply_vanish_hits(attacker, target, target_pid, [damage]) when damage > 1,
    do: EquipVanish.after_hit(attacker, target, target_pid, magic_attack_flag())

  defp apply_vanish_hits(_attacker, _target, _target_pid, _damages), do: :ok

  defp magic_attack_flag, do: BattleFlags.build(:magic, :long, true)

  defp decide_coma(attacker, target, damages) do
    case Enum.find(damages, &(&1 > 0)) do
      nil -> :unchecked
      _damage -> EquipComa.trigger?(attacker, target)
    end
  end

  defp decide_coma_once(:unchecked, attacker, target, damage),
    do: decide_coma(attacker, target, [damage])

  defp decide_coma_once(decision, _attacker, _target, _damage), do: decision

  defp damage_source(%{unit_type: unit_type, unit_id: unit_id}, :player),
    do: {unit_type, unit_id}

  defp damage_source(%{unit_type: unit_type, unit_id: unit_id}, target_type)
       when unit_type == :homunculus or target_type == :homunculus,
       do: {unit_type, unit_id}

  defp damage_source(%{unit_id: unit_id}, _target_type), do: unit_id

  defp prepare_magic_hit(:skill_unit, _target_id, damage, hit_info, _attacker_id),
    do: {damage, hit_info}

  defp prepare_magic_hit(target_type, target_id, damage, hit_info, attacker_id) do
    DamageApplication.prepare_unit_damage(target_type, target_id, damage, hit_info, attacker_id)
  end
end
