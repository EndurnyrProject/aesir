defmodule Aesir.ZoneServer.Mmo.Combat do
  @moduledoc """
  Core combat system orchestrating damage calculations and application.
  """

  require Logger

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc """
  Executes an attack from player to target.

  Flow:
  1. Validate attack (range, target exists, cooldowns)
  2. Convert unit states to combatants
  3. Check hit/miss and calculate damage
  4. Apply damage to target
  5. Broadcast combat packets
  6. Handle death/rewards if applicable

  ## Parameters
    - player_state: Player state containing all required combat information
    - stats: Player stats from session
    - target_id: ID of the target entity

  ## Returns
    - :ok if attack was successful
    - {:error, reason} if attack failed
  """
  @spec execute_attack(map(), map(), integer()) :: :ok | {:error, atom()}
  def execute_attack(stats, player_state, target_id) do
    # Create player combatant - player_state already implements to_combatant
    # But we need to update the stats first
    player_state = %{player_state | stats: stats}
    attacker_combatant = player_state.__struct__.to_combatant(player_state)

    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <-
           validate_attack_with_combatants(attacker_combatant, target_combatant,
             projectile?: true
           ),
         {:ok, combat_result} <-
           check_hit_and_calculate_damage_with_combatants(attacker_combatant, target_combatant) do
      resolve_player_attack(
        combat_result,
        player_state,
        target_state,
        attacker_combatant,
        target_combatant,
        target_pid,
        target_type,
        target_id
      )
    end
  end

  @doc """
  Resolves a target's type and authoritative spatial position.

  Player IDs take precedence over mob IDs when they collide.
  """
  defdelegate resolve_target_position(target_id), to: TargetResolver

  defp resolve_player_attack(
         {:miss},
         _player_state,
         _target_state,
         attacker,
         target,
         _target_pid,
         target_type,
         target_id
       ) do
    Logger.debug("Combat: Player #{attacker.unit_id} attack missed #{target_type} #{target_id}")
    broadcast_to_nearby_players(target, PacketFactory.build_miss_packet(attacker, target))
    :ok
  end

  defp resolve_player_attack(
         {:perfect_dodge},
         _player_state,
         _target_state,
         attacker,
         target,
         _target_pid,
         target_type,
         target_id
       ) do
    Logger.debug(
      "Combat: Player #{attacker.unit_id} attack perfect dodged #{target_type} #{target_id}"
    )

    broadcast_to_nearby_players(
      target,
      PacketFactory.build_perfect_dodge_packet(attacker, target)
    )

    :ok
  end

  defp resolve_player_attack(
         {:hit, damage_result},
         _player_state,
         _target_state,
         attacker,
         target,
         target_pid,
         :player,
         target_id
       ) do
    handle_player_attack_hit(damage_result, attacker, target, target_pid, :player, target_id, 1)
    :ok
  end

  defp resolve_player_attack(
         {:hit, damage_result},
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id
       ) do
    with :ok <-
           handle_player_attack_hit(
             damage_result,
             attacker,
             target,
             target_pid,
             target_type,
             target_id,
             attack_hits(player_state)
           ) do
      roll_equipment_breaks(player_state, target_state, target_type, target_pid)
      dispatch_dealt_damage(attacker, target_type, target_id, damage_result)
      :ok
    end
  end

  # Rolls equipment breaks once per confirmed weapon hit (never once per
  # multi-hit) and dispatches each decision to the owning session. `execute_attack`
  # runs inside the attacker's `PlayerSession`, so a `:self` break is a cast to
  # `self()`; a `:target` break goes to `target_pid`. The resolver only emits
  # `:target` decisions for player victims (mob "equipment" never breaks in
  # Renewal), so mob targets receive nothing.
  #
  defp roll_equipment_breaks(player_state, target_state, target_type, target_pid) do
    target_type
    |> break_target(target_state)
    |> maybe_roll(player_state, target_pid)
  end

  defp break_target(:player, target_state), do: {:player, target_state.stats}
  defp break_target(target_type, target_state), do: {target_type, target_state}

  # NOTE: player victims are skipped entirely: `handle_player_attack_hit/7`
  # returns `{:error, :pvp_not_implemented}` and applies no damage, so rolling a
  # break here would silently destroy another player's gear with no hit dealt.
  # The enemy-break wiring (the `{:player, ...}` tuple above and the `:target`
  # dispatch below) stays built but unreachable; whoever implements PvP removes
  # the damage stub in `handle_player_attack_hit/7` AND this gate together.
  defp maybe_roll({:player, _victim_stats}, _player_state, _target_pid), do: :ok

  defp maybe_roll(target, player_state, target_pid) do
    player_state.stats
    |> EquipBreak.resolve(target)
    |> Enum.each(&dispatch_break(&1, target_pid))
  end

  defp dispatch_break({:self, slot}, _target_pid),
    do: GenServer.cast(self(), {:break_equip, break_slot(slot)})

  defp dispatch_break({:target, slot}, target_pid),
    do: GenServer.cast(target_pid, {:break_equip, break_slot(slot)})

  defp break_slot(:weapon), do: :right_hand
  defp break_slot(:armor), do: :armor

  # Fires the attacker's `on_dealt_damage` statuses once per confirmed weapon
  # swing (never per multi-hit), the attacker-side counterpart of the victim's
  # `on_damage`. Sited after the damage casts, the attack broadcast and the
  # break roll, so every effect of the triggering hit is already queued on the
  # victim's mailbox ahead of anything an auto-cast sends it.
  #
  # Skill units are excluded: they are not living targets and hold no state a
  # proc could act on (rAthena procs autospell against `bl` units only).
  defp dispatch_dealt_damage(_attacker, :skill_unit, _target_id, _damage_result), do: :ok

  defp dispatch_dealt_damage(attacker, target_type, target_id, damage_result) do
    hit_info = %{
      target: {target_type, target_id},
      damage: damage_result.damage,
      element: attacker.weapon.element
    }

    :player
    |> StatusInterpreter.on_dealt_damage(attacker.unit_id, hit_info)
    |> Enum.each(&drain_auto_cast/1)
  end

  # `execute_attack/3` runs inside the attacker's own `PlayerSession`, so the
  # auto-cast is a cast to `self()` (like a `:self` equipment break): it runs
  # after the current message finishes, on state the session has already
  # committed. `SC_AUTOSPELL` is the only producer today; the session's
  # `{:auto_cast, ...}` handler routes it to the interpreter's restricted entry.
  #
  # This is also why the proc cannot recurse: the bolt it casts is magic, and
  # only the weapon-attack path above ever reaches `dispatch_dealt_damage/4`.
  defp drain_auto_cast({:auto_cast, skill_name, level, target}) do
    case Catalog.by_name(skill_name) do
      {:ok, definition} ->
        GenServer.cast(self(), {:auto_cast, definition.id, level, target})

      :error ->
        raise "auto-cast of unknown skill #{inspect(skill_name)} at level #{level}: " <>
                "a status named a skill absent from the catalog"
    end
  end

  # The number of basic-attack hits to deliver, driven by passive procs (e.g.
  # Double Attack's `%{multi_hit: 2, chance: 7 * level}`). The proc's `:chance`
  # (default 100 when absent) is rolled out of 100 before the multi-hit is
  # delivered; a failed roll (or no proc) delivers a single hit.
  defp attack_hits(player_state) do
    case Passives.attack_procs(player_state) do
      %{multi_hit: n} = proc when n > 1 ->
        chance = Map.get(proc, :chance, 100)
        if :rand.uniform(100) <= chance, do: n, else: 1

      _ ->
        1
    end
  end

  defp handle_player_attack_hit(
         damage_result,
         attacker_combatant,
         target_combatant,
         target_pid,
         target_type,
         target_id,
         hits
       ) do
    damage = damage_result.damage
    is_critical = damage_result.is_critical

    Logger.debug(
      "Combat: Player #{attacker_combatant.unit_id} attacking #{target_type} #{target_id} for #{damage} damage#{if hits > 1, do: " x#{hits}", else: ""}#{if is_critical, do: " (CRITICAL)", else: ""}"
    )

    case target_type do
      :mob ->
        hit_info = %{
          dmg_type: :physical,
          is_short: true,
          element: attacker_combatant.weapon.element,
          skill_id: nil,
          skill_level: nil,
          from_caster?: true
        }

        Enum.each(1..hits//1, fn _ ->
          apply_unit_damage(
            :mob,
            target_pid,
            target_id,
            damage,
            hit_info,
            attacker_combatant.unit_id
          )
        end)

        broadcast_basic_attack(attacker_combatant, target_combatant, damage_result, hits)

      :player ->
        Logger.warning("PvP combat not yet implemented")
        {:error, :pvp_not_implemented}

      :skill_unit ->
        apply_skill_unit_target_damage(
          target_pid,
          target_id,
          damage,
          attacker_combatant.unit_id,
          attacker_combatant,
          target_combatant,
          damage_result
        )
    end
  end

  defp broadcast_basic_attack(attacker, target, damage_result, hits) do
    broadcast_to_nearby_players(
      target,
      PacketFactory.build_attack_packet(attacker, target, damage_result, hits)
    )

    :ok
  end

  defp apply_skill_unit_target_damage(
         manager_pid,
         target_id,
         damage,
         attacker_id,
         attacker,
         target,
         damage_result
       ) do
    with :ok <-
           apply_skill_unit_target_damage(manager_pid, target_id, damage, {:player, attacker_id}) do
      broadcast_skill_unit_attack(attacker, target, damage_result)
    end
  end

  defp apply_skill_unit_target_damage(manager_pid, target_id, damage, source),
    do: DamageApplication.damage_skill_unit(manager_pid, target_id, damage, source)

  defp broadcast_skill_unit_attack(attacker, target, damage_result) do
    packet = PacketFactory.build_attack_packet(attacker, target, damage_result)
    broadcast_to_nearby_players(target, packet)
  end

  @doc """
  Deals damage to a target entity (used by status effects).

  This is a simplified version of execute_attack that bypasses
  validation and is used by status effects and other systems.
  """
  @spec deal_damage(integer(), integer(), atom(), atom()) :: :ok | {:error, atom()}
  def deal_damage(target_id, damage, element \\ :neutral, source_type \\ :status_effect) do
    with {:ok, target_pid, _target_state, target_type} <- get_target_unit_state(target_id) do
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
  Broadcasts a heal to a player session via PubSub.

  An offline player (no subscriber) is a silent no-op. Mobs are never healed;
  for undead/demon targets use the damage path instead.
  """
  defdelegate apply_heal(target_id, amount, source_id \\ nil), to: DamageApplication

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
  @spec execute_magic_damage(struct(), integer(), non_neg_integer(), keyword()) ::
          :ok | {:error, atom()}
  def execute_magic_damage(caster_state, target_id, amount, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    element = Keyword.get(opts, :element, :neutral)

    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_attack_with_combatants(attacker, target, opts),
         :ok <- Targeting.validate_enemy(attacker, target) do
      damage =
        amount
        |> DamageShared.apply_element(element, target)
        |> DamageShared.clamp_min_one()

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
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        ),
        attacker,
        target,
        packet
      )
    end
  end

  @doc """
  Resolves a unit id to its combatant struct.

  Wraps the unit-state lookup so callers outside this module (e.g. ground
  skill-units resolving their caster once per tick) can build a `Combatant` without
  knowing how players and mobs are stored. Returns `{:error, reason}` when the unit
  is gone (logged out, despawned), so the caller can skip cleanly.
  """
  defdelegate resolve_combatant(unit_id), to: TargetResolver

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
  Applies a magic ground-unit hit with optional multi-hit, flat-MATK, and target
  walk-delay traits.

  `:divide_hits_for_player?` mirrors Renewal Fire Pillar's negative `div`
  behavior for player targets: its total damage is divided by the hit count while
  the client receives the multi-hit animation.
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
    dst_delay = Keyword.get(opts, :dst_delay, 0)
    divide_hits? = unit_type == :player and Keyword.get(opts, :divide_hits_for_player?, false)

    with {:ok, target} <- resolve_combatant(target_id),
         {:ok, {tx, ty, map_name}} <- SpatialIndex.get_unit_position(unit_type, target_id),
         damage <- sum_magic_hits(caster, target, element, skill_ratio, hit_count, bonus_matk),
         damage <- if(divide_hits?, do: div(damage, hit_count), else: damage),
         {:ok, target_pid, _target_state, _target_type} <-
           get_target_unit_state(unit_type, target_id) do
      {damage, packet_divisions} =
        case Keyword.fetch(opts, :hit_divisions) do
          {:ok, hit_divisions} -> normalize_hit_divisions(damage, hit_divisions)
          :error -> {damage, if(divide_hits?, do: -hit_count, else: hit_count)}
        end

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
      deal_damage(target_id, damage, element, :skill_unit)

      if dst_delay > 0 do
        unit_session(unit_type).apply_walk_delay(target_pid, dst_delay)
      end

      :ok
    end
  end

  defp normalize_hit_divisions(damage, hit_divisions) when hit_divisions < 0 do
    divisions = abs(hit_divisions)
    {div(damage, divisions) * divisions, divisions}
  end

  defp normalize_hit_divisions(damage, hit_divisions), do: {damage, hit_divisions}

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
  @spec execute_magic_attack(struct(), integer(), keyword()) :: :ok | {:error, atom()}
  def execute_magic_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    element = Keyword.get(opts, :element, :neutral)
    hits = Keyword.get(opts, :hit_count, 1)

    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_attack_with_combatants(attacker, target, opts),
         :ok <- Targeting.validate_enemy(attacker, target) do
      total = sum_magic_hits(attacker, target, element, skill_ratio, hits)

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          total,
          div: hits
        )

      apply_and_broadcast_magic_damage(
        target_type,
        target_pid,
        target_id,
        total,
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        ),
        attacker,
        target,
        packet
      )
    end
  end

  defp sum_magic_hits(attacker, target, element, skill_ratio, hits, bonus_matk \\ 0) do
    Enum.reduce(1..hits//1, 0, fn _hit, acc ->
      {:ok, %{damage: damage}} =
        MagicDamageCalculator.calculate_magic_damage(attacker, target,
          element: element,
          skill_ratio: skill_ratio,
          bonus_matk: bonus_matk
        )

      acc + damage
    end)
  end

  defp apply_magic_damage(:skill_unit, manager_pid, target_id, damage, _hit_info, attacker) do
    source = if attacker, do: {attacker.unit_type, attacker.unit_id}
    apply_skill_unit_target_damage(manager_pid, target_id, damage, source)
  end

  defp apply_magic_damage(target_type, target_pid, target_id, damage, hit_info, attacker) do
    attacker_id = if attacker, do: attacker.unit_id
    apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker_id)
    :ok
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

  @doc """
  Executes a center+radius magic splash against every offensive target in range.

  Reuses `splash_targets/4` to find the hit set, runs each target through
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
      |> splash_targets(center, radius, attacker)
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

  defp filter_splash_line_of_sight(targets, _map_name, _center, false), do: targets

  defp filter_splash_line_of_sight(targets, map_name, center, true) do
    Enum.filter(targets, &splash_target_visible?(map_name, center, &1))
  end

  defp splash_target_visible?(map_name, center, {unit_type, target_id}) do
    case get_target_unit_state(unit_type, target_id) do
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
           get_target_unit_state(unit_type, target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Targeting.validate_enemy(attacker, target),
         {:ok, %{damage: damage}} <-
           MagicDamageCalculator.calculate_magic_damage(attacker, target,
             element: element,
             skill_ratio: skill_ratio
           ) do
      damage = div(damage, divisor)
      {tx, ty} = target.position

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage
        )

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)

      hit_info =
        magic_hit_info(element,
          skill_id: skill_id,
          skill_level: skill_level,
          from_caster?: true
        )

      apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker.unit_id)
      [target_ref]
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

    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Targeting.validate_enemy(attacker, target),
         {:ok, %{damage: damage}} <-
           MiscDamageCalculator.calculate_misc_damage(attacker, target,
             base_damage: base_damage,
             element: element
           ) do
      {tx, ty} = target.position

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage
        )

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)

      hit_info = %{
        dmg_type: :misc,
        is_short: false,
        element: element,
        skill_id: skill_id,
        skill_level: skill_level
      }

      apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker.unit_id)
      :ok
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
  """
  @spec execute_misc_splash(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_misc_splash(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)

    targets = splash_targets(attacker.map_name, center, radius, attacker)

    Enum.flat_map(targets, fn {_unit_type, target_id} ->
      apply_misc_splash_hit(attacker, target_id, skill_id, skill_level, element, base_damage)
    end)
  end

  defp apply_misc_splash_hit(attacker, target_id, skill_id, skill_level, element, base_damage) do
    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Targeting.validate_enemy(attacker, target),
         {:ok, %{damage: damage}} <-
           MiscDamageCalculator.calculate_misc_damage(attacker, target,
             base_damage: base_damage,
             element: element
           ) do
      {tx, ty} = target.position

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage
        )

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)

      hit_info = %{
        dmg_type: :misc,
        is_short: false,
        element: element,
        skill_id: skill_id,
        skill_level: skill_level
      }

      apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker.unit_id)
      [target_id]
    else
      _ -> []
    end
  end

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
      Keyword.take(opts, [:skill_ratio, :skip_crit, :bonus_atk, :fixed_damage, :element])

    # NOTE: skills always connect here; skill miss/flee isn't modeled yet.
    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_attack_with_combatants(attacker, target, projectile?: true),
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

  Resolves units via the spatial index, filters to living enemies (excluding
  the caster and same-party/guild players), then runs each through the shared
  single-target damage path **without** the per-target attack-range gate — the
  radius already bounds the hit set. Returns the list of hit target ids, consumed
  by knockback (#6).

  The spatial index filters by Manhattan distance (a diamond), but skill splash
  AoE is a Chebyshev square. We query a Manhattan radius of `2 * radius` so the
  full square is covered (a corner cell at `{radius, radius}` has Manhattan
  `2 * radius`), then post-filter to the Chebyshev square. Dead mobs (hp <= 0)
  are excluded so they receive no phantom damage or broadcast.

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
    calc_opts = Keyword.take(opts, [:skill_ratio, :skip_crit])

    attacker.map_name
    |> splash_targets(center, radius, attacker)
    |> Enum.flat_map(fn {_unit_type, target_id} ->
      with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
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
  Selects the valid offensive targets for a center+radius splash/footprint.

  See `Aesir.ZoneServer.Mmo.Combat.SplashTargets.select/4`.
  """
  defdelegate splash_targets(map_name, center, radius, caster), to: SplashTargets, as: :select

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

      broadcast_to_nearby_players(target, packet)

      hit_info = %{
        dmg_type: :physical,
        is_short: attacker.attack_range <= 3,
        element: :neutral,
        skill_id: skill_id,
        skill_level: skill_level
      }

      apply_unit_damage(
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

  # Transitional wrappers over DamageApplication; removed as the attack paths
  # move into their own modules.
  defp apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker_id),
    do:
      DamageApplication.apply_unit_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        hit_info,
        attacker_id
      )

  defp unit_session(unit_type), do: DamageApplication.unit_session(unit_type)

  @doc """
  Knocks a unit back away from `{from_x, from_y}`, collision-aware.

  See `Aesir.ZoneServer.Mmo.Combat.Knockback.knockback/5`.
  """
  defdelegate knockback(unit_type, unit_id, from_x, from_y, distance), to: Knockback

  @doc """
  Executes an attack from mob to player.

  Flow:
  1. Validate attack (range, target exists, cooldowns)
  2. Convert unit states to combatants
  3. Check hit/miss and calculate damage
  4. Apply damage to player
  5. Broadcast combat packets

  ## Parameters
    - mob_state: Mob state containing all required combat information
    - target_id: ID of the target player

  ## Returns
    - :ok if attack was successful
    - {:error, reason} if attack failed
  """
  @spec execute_mob_attack(map(), integer()) :: :ok | {:error, atom()}
  def execute_mob_attack(mob_state, target_id) do
    # Convert mob state to combatant
    attacker_combatant = mob_state.__struct__.to_combatant(mob_state)

    with {:ok, target_pid, target_state, :player} <- get_target_unit_state(target_id),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_mob_attack_with_combatants(attacker_combatant, target_combatant),
         {:ok, combat_result} <-
           check_hit_and_calculate_damage_with_combatants(attacker_combatant, target_combatant) do
      case combat_result do
        {:miss} ->
          Logger.debug(
            "Combat: Mob #{attacker_combatant.unit_id} attack missed player #{target_id}"
          )

          # Broadcast miss packet to nearby players
          miss_packet = PacketFactory.build_miss_packet(attacker_combatant, target_combatant)
          broadcast_to_nearby_players(target_combatant, miss_packet)

        {:perfect_dodge} ->
          Logger.debug(
            "Combat: Mob #{attacker_combatant.unit_id} attack perfect dodged by player #{target_id}"
          )

          # Broadcast perfect dodge packet to nearby players
          dodge_packet =
            PacketFactory.build_perfect_dodge_packet(attacker_combatant, target_combatant)

          broadcast_to_nearby_players(target_combatant, dodge_packet)

        {:hit, damage_result} ->
          handle_mob_attack_hit(
            damage_result,
            attacker_combatant,
            target_combatant,
            target_pid,
            target_id
          )
      end

      :ok
    end
  end

  defp handle_mob_attack_hit(
         damage_result,
         attacker_combatant,
         target_combatant,
         target_pid,
         target_id
       ) do
    damage = damage_result.damage
    is_critical = damage_result.is_critical

    Logger.debug(
      "Combat: Mob #{attacker_combatant.unit_id} attacking player #{target_id} for #{damage} damage#{if is_critical, do: " (CRITICAL)", else: ""}"
    )

    # Show the hit animation/damage number first, then apply HP loss so the
    # SP_HP update (and any death) follows the visible strike.
    attack_packet =
      PacketFactory.build_attack_packet(attacker_combatant, target_combatant, damage_result)

    broadcast_to_nearby_players(target_combatant, attack_packet)

    # NOTE: no equipment-break roll on the mob path — mob attackers carry no break
    # bonuses and natural break is player-only; this is the future hook for
    # mob-skill-driven breaks (rAthena `skill_break_equip`) once those exist.
    hit_info = %{
      dmg_type: :physical,
      is_short: attacker_combatant.attack_range <= 3,
      element: attacker_combatant.weapon.element,
      skill_id: nil,
      skill_level: nil,
      from_caster?: true
    }

    apply_unit_damage(
      :player,
      target_pid,
      target_id,
      damage,
      hit_info,
      attacker_combatant.unit_id
    )
  end

  # Transitional wrappers over TargetResolver; removed as the attack paths move
  # into their own modules.
  defp get_target_unit_state(unit_type, target_id),
    do: TargetResolver.resolve(unit_type, target_id)

  defp get_target_unit_state(target_id), do: TargetResolver.resolve(target_id)

  defp ensure_targetable(target_state, target_type),
    do: TargetResolver.ensure_targetable(target_state, target_type)

  # Transitional wrappers over AttackValidator; removed as the attack paths move
  # into their own modules.
  defp validate_attack_with_combatants(attacker_combatant, target_combatant, opts),
    do: AttackValidator.validate(attacker_combatant, target_combatant, opts)

  defp validate_mob_attack_with_combatants(attacker_combatant, target_combatant),
    do: AttackValidator.validate_mob_attack(attacker_combatant, target_combatant)

  defp check_hit_and_calculate_damage_with_combatants(attacker_combatant, defender_combatant) do
    # Convert combatants to format expected by HitCalculations
    attacker_stats = %{
      hit: attacker_combatant.combat_stats.hit,
      char_id: attacker_combatant.unit_id
    }

    defender_stats = %{
      flee: defender_combatant.combat_stats.flee,
      perfect_dodge: defender_combatant.combat_stats.perfect_dodge,
      unit_id: defender_combatant.unit_id
    }

    case HitCalculations.calculate_hit_result(attacker_stats, defender_stats) do
      :hit ->
        # Calculate damage using the new DamageCalculator
        case DamageCalculator.calculate_damage(attacker_combatant, defender_combatant) do
          {:ok, damage_result} -> {:ok, {:hit, damage_result}}
          {:error, reason} -> {:error, reason}
        end

      :miss ->
        {:ok, {:miss}}

      :perfect_dodge ->
        {:ok, {:perfect_dodge}}
    end
  end

  defp broadcast_to_nearby_players(target, packet),
    do: DamageApplication.broadcast_nearby(target, packet)
end
