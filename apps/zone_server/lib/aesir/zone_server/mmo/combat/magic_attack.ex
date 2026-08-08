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
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @bolts %{
    14 => {:water, 100},
    19 => {:fire, 100},
    20 => {:wind, 100},
    90 => {:earth, 200}
  }

  @doc """
  Deals damage to a target entity (used by status effects).

  This is a simplified version of the attack paths that bypasses validation and
  is used by status effects and other systems.
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
        magic_hit_info(element, []),
        nil
      )
    end
  end

  @doc """
  Applies an explicit damage amount as a single magic hit of the given element,
  bypassing MATK and MDEF.

  Intended for the Heal undead/demon branch: the already-computed heal value is
  delivered as holy damage, so MATK and MDEF play no role — only the target's
  element resistance modifies the amount. Resolves and range-checks the target
  identically to `execute_magic_attack/3`, broadcasts a `SkillDamage` packet, and
  applies the final damage.

  ## Options

    - `:skill_id` / `:skill_level` — identify the skill for the damage packet (required).
    - `:element` — attack element applied against the target's element resistance
      (default `:neutral`).
    - `:skip_range` — skip only the distance check (which gates on the caster's
      *weapon* attack range) for a cast whose skill range the interpreter already
      validated; map, life, and enemy-relation checks still run (default `false`).

  ## Returns

    - `:ok` on success.
    - `{:error, reason}` when the target is invalid, friendly, dead, or out of range.
  """
  @spec execute_magic_damage(struct(), integer() | Ref.t(), non_neg_integer(), keyword()) ::
          :ok | {:error, atom()}
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
         :ok <- Targeting.validate_enemy(attacker, target) do
      damage =
        amount
        |> DamageShared.apply_element(element, target, DamageShared.attacker_modifiers(attacker))
        |> DamageShared.clamp_min_one()

      hit_info =
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        )

      {damage, hit_info} =
        prepare_magic_hit(
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
          damage
        )

      apply_and_broadcast_magic_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        hit_info,
        attacker,
        target,
        packet
      )
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

  `:divide_hits_for_player?` mirrors Renewal Fire Pillar's negative `div`
  behavior for player targets: its total damage is divided by the hit count while
  the client receives the multi-hit animation.

  `:damage_scale` (default `1`) multiplies the final computed damage before it is
  applied and re-clamps to a floor of 1 - the seam Grand Cross uses to halve the
  self-damage its own footprint deals to its caster.
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
        ) :: :ok | {:error, atom()}
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
    hit_count = Keyword.get(opts, :hit_count, 1)
    bonus_matk = Keyword.get(opts, :bonus_matk, 0)
    fixed_damage = Keyword.get(opts, :fixed_damage)
    dst_delay = Keyword.get(opts, :dst_delay, 0)
    divide_hits? = unit_type == :player and Keyword.get(opts, :divide_hits_for_player?, false)

    with {:ok, target_pid, target_state, target_type} <-
           resolve_skill_unit_target(unit_type, target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         :ok <- ensure_living_target(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         {:ok, {tx, ty, map_name}} <- SpatialIndex.get_unit_position(unit_type, target_id),
         damage <-
           skill_unit_damage(
             caster,
             target,
             element,
             skill_ratio,
             hit_count,
             bonus_matk,
             skill_id,
             fixed_damage
           ),
         damage <- if(divide_hits?, do: div(damage, hit_count), else: damage),
         damage <- scale_damage(damage, Keyword.get(opts, :damage_scale, 1)) do
      {damage, packet_divisions} =
        case Keyword.fetch(opts, :hit_divisions) do
          {:ok, hit_divisions} -> normalize_hit_divisions(damage, hit_divisions)
          :error -> {damage, if(divide_hits?, do: -hit_count, else: hit_count)}
        end

      hit_info =
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: false
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

      Broadcast.to_in_range(map_name, tx, ty, Config.view_range(), packet)
      apply_magic_damage(target_type, target_pid, target_id, damage, hit_info, caster)

      if dst_delay > 0 do
        apply_walk_delay(unit_type, target_pid, dst_delay)
      end

      :ok
    end
  end

  @doc """
  Executes one of the four canonical bolt skills without entering a player cast path.

  The selected bolt id is the damage and packet skill id. Canonical element and
  hit count cannot be overridden; callers may override the default per-hit ratio
  for effects attached to the selected bolt.
  """
  @spec execute_bolt(struct(), integer() | Ref.t(), integer(), pos_integer(), keyword()) ::
          :ok | {:error, atom()}
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
            hit_count: level,
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
  once per hit (`:hit_count` hits, each at `:skill_ratio` of MATK in `:element`),
  broadcasts a single `ZC_NOTIFY_SKILL` packet with `div = hits` carrying the
  summed damage, then applies that summed damage through the shared unit-damage
  path. Used by direct nukes (bolts, Soul Strike, Frost Diver).

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base MATK each hit deals (default `100`)
    - `:bonus_matk` - flat MATK added after the skill-ratio step (default `0`)
    - `:element` - the skill's magic element (default `:neutral`)
    - `:hit_count` - number of magic hits to deliver (default `1`)
    - `:skip_range` - skip only the distance check, which gates on the caster's
      *weapon* attack range. Direct nukes must pass it: their skill range is
      validated by the interpreter at cast start and castend, and the weapon-range
      gate would fizzle any cast beyond melee reach. Map, life, and enemy-relation
      checks still run (default `false`)

  ## Returns
    - :ok if the skill connected
    - {:error, reason} if the target was invalid, friendly, dead, or out of range
  """
  @spec execute_magic_attack(struct(), integer() | Ref.t(), keyword()) :: :ok | {:error, atom()}
  def execute_magic_attack(caster_state, target_ref, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    bonus_matk = Keyword.get(opts, :bonus_matk, 0)
    element = Keyword.get(opts, :element, :neutral)
    hits = Keyword.get(opts, :hit_count, 1)

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         target_id <- target.unit_id,
         :ok <- AttackValidator.validate(attacker, target, opts),
         :ok <- Targeting.validate_enemy(attacker, target) do
      damages =
        magic_hit_damages(
          attacker,
          target,
          element,
          skill_ratio,
          hits,
          bonus_matk,
          skill_id,
          opts
        )

      deliver_magic_hits(
        target_type,
        target_pid,
        target_id,
        damages,
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        ),
        attacker,
        target,
        {skill_id, skill_level}
      )
    end
  end

  @doc """
  Executes a center+radius magic splash against every offensive target in range.

  Reuses `SplashTargets.select/4` to find the hit set, runs each target through
  `MagicDamageCalculator` (one magic hit at `:skill_ratio` in `:element`),
  broadcasts a `ZC_NOTIFY_SKILL` packet per target and applies the damage.
  With `:split` the total damage is divided evenly across the number of targets
  hit (Napalm Beat); without it each target takes the full per-target damage.
  Returns the typed `{unit_type, unit_id}` references that were hit.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base MATK each target takes (default `100`)
    - `:element` - the skill's magic element (default `:neutral`)
    - `:split` - divide total damage by the number of targets hit (default `false`)
    - `:line_of_sight` - require an unobstructed projectile path (default `false`)
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

    targets =
      attacker.map_name
      |> SplashTargets.select(center, radius, attacker)
      |> filter_splash_line_of_sight(attacker.map_name, center, line_of_sight)

    divisor = if split, do: max(length(targets), 1), else: 1

    Enum.flat_map(targets, fn target_ref ->
      apply_magic_splash_hit(
        attacker,
        target_ref,
        skill_id,
        skill_level,
        element,
        skill_ratio,
        divisor
      )
    end)
  end

  # Post-calculation damage scale for a skill-unit hit (Grand Cross halves its
  # own caster's self-damage). A scale of 1 is the untouched default; any other
  # factor multiplies the computed damage and re-clamps to a floor of 1.
  defp scale_damage(damage, 1), do: damage
  defp scale_damage(damage, scale), do: max(1, trunc(damage * scale))

  defp normalize_hit_divisions(damage, hit_divisions) when hit_divisions < 0 do
    divisions = abs(hit_divisions)
    {div(damage, divisions) * divisions, divisions}
  end

  defp normalize_hit_divisions(damage, hit_divisions), do: {damage, hit_divisions}

  defp skill_unit_damage(
         attacker,
         target,
         element,
         skill_ratio,
         hits,
         bonus_matk,
         skill_id,
         nil
       ) do
    sum_magic_hits(attacker, target, element, skill_ratio, hits, bonus_matk, skill_id)
  end

  defp skill_unit_damage(
         attacker,
         target,
         element,
         _skill_ratio,
         _hits,
         _bonus_matk,
         _skill_id,
         fixed_damage
       )
       when is_integer(fixed_damage) and fixed_damage >= 0 do
    fixed_damage
    |> DamageShared.apply_element(element, target, DamageShared.attacker_modifiers(attacker))
    |> DamageShared.clamp_min_one()
  end

  defp sum_magic_hits(attacker, target, element, skill_ratio, hits, bonus_matk, skill_id) do
    attacker
    |> magic_hit_damages(target, element, skill_ratio, hits, bonus_matk, skill_id, [])
    |> Enum.sum()
  end

  defp magic_hit_damages(attacker, target, element, skill_ratio, hits, bonus_matk, skill_id, opts) do
    Enum.map(1..hits//1, fn _hit ->
      {:ok, %{damage: damage}} =
        MagicDamageCalculator.calculate_magic_damage(attacker, target,
          element: element,
          skill_ratio: skill_ratio,
          bonus_matk: bonus_matk,
          skill_id: skill_id,
          ignore_mdef: Keyword.get(opts, :ignore_mdef, false)
        )

      damage
    end)
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

  # The `hit_info` a defending status' `absorb_damage/4` hook receives. `skill_id`
  # / `skill_level` identify the incoming skill (nil for a basic attack), and
  # `from_caster?` marks a hit whose damage source is the caster themselves —
  # rAthena's `src == dsrc`. It is true for a direct cast including its splash,
  # and false for a placed skill unit's tick or a status DoT. Statuses that must
  # not over-absorb (Magic Rod) match on it positively, so a caller that cannot
  # assert the origin should leave it false.
  defp magic_hit_info(element, opts) do
    %{
      dmg_type: :magic,
      is_short: false,
      element: element,
      skill_id: Keyword.get(opts, :skill_id),
      skill_level: Keyword.get(opts, :skill_level),
      from_caster?: Keyword.get(opts, :from_caster?, false)
    }
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
         element,
         skill_ratio,
         divisor
       ) do
    with {:ok, target_pid, target_state, target_type} <-
           TargetResolver.resolve(unit_type, target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Targeting.validate_enemy(attacker, target),
         {:ok, %{damage: damage}} <-
           MagicDamageCalculator.calculate_magic_damage(attacker, target,
             element: element,
             skill_ratio: skill_ratio,
             skill_id: skill_id
           ) do
      damage = div(damage, divisor)
      {tx, ty} = target.position

      hit_info =
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        )

      source = damage_source(attacker, target_type)

      {damage, hit_info} =
        prepare_magic_hit(target_type, target_id, damage, hit_info, source)

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage
        )

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)

      DamageApplication.apply_unit_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        hit_info,
        source
      )

      [target_ref]
    else
      _ -> []
    end
  end

  defp deliver_magic_hits(
         target_type,
         target_pid,
         target_id,
         damages,
         hit_info,
         attacker,
         target,
         {skill_id, skill_level}
       ) do
    source = damage_source(attacker, target_type)

    prepared_hits =
      Enum.map(damages, fn damage ->
        prepare_magic_hit(target_type, target_id, damage, hit_info, source)
      end)

    if length(prepared_hits) > 1 and
         prepared_hits |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() > 1 do
      Enum.each(prepared_hits, fn {damage, prepared_hit_info} ->
        packet =
          PacketFactory.build_splash_damage_packet(
            attacker.unit_id,
            target_id,
            skill_id,
            skill_level,
            damage
          )

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
      end)
    else
      {_, prepared_hit_info} = List.first(prepared_hits)
      total = Enum.sum(Enum.map(prepared_hits, &elem(&1, 0)))

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          total,
          div: length(prepared_hits)
        )

      apply_and_broadcast_magic_damage(
        target_type,
        target_pid,
        target_id,
        total,
        prepared_hit_info,
        attacker,
        target,
        packet
      )
    end
  end

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
