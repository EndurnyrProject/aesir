defmodule Aesir.ZoneServer.Mmo.Combat do
  @moduledoc """
  Core combat system orchestrating damage calculations and application.
  """

  require Logger

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.Knockback
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id, as: SkillUnitId
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  # ZC_NOTIFY_SKILL `type` for a splash/area skill hit (e_damage_type DMG_SPLASH).
  @dmg_splash 5

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
  @spec resolve_target_position(integer()) ::
          {:ok, :player | :mob | :skill_unit, {integer(), integer(), String.t()}}
          | {:error, :target_not_found}
  def resolve_target_position(target_id) do
    if SkillUnitId.skill_unit?(target_id) do
      resolve_skill_unit_position(target_id)
    else
      resolve_standard_target_position(target_id)
    end
  end

  defp resolve_standard_target_position(target_id) do
    case SpatialIndex.get_unit_position(:player, target_id) do
      {:ok, position} -> {:ok, :player, position}
      {:error, :not_found} -> resolve_mob_target_position(target_id)
    end
  end

  defp resolve_mob_target_position(target_id) do
    case SpatialIndex.get_unit_position(:mob, target_id) do
      {:ok, position} -> {:ok, :mob, position}
      {:error, :not_found} -> {:error, :target_not_found}
    end
  end

  defp resolve_skill_unit_position(target_id) do
    with {:ok, {_module, _cell, manager_pid}} when is_pid(manager_pid) <-
           UnitRegistry.get_unit(:skill_unit, target_id),
         {:ok, _cell} <- SkillUnitManager.targetable_cell(manager_pid, target_id),
         {:ok, position} <- SpatialIndex.get_unit_position(:skill_unit, target_id) do
      {:ok, :skill_unit, position}
    else
      _ -> {:error, :target_not_found}
    end
  end

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
          element: attacker_combatant.weapon.element
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

  defp apply_skill_unit_target_damage(manager_pid, target_id, damage, source) do
    case SkillUnitManager.damage_targetable_cell(manager_pid, target_id, damage, source) do
      {:ok, _cell} -> :ok
      {:destroyed, _cell} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

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

      apply_magic_damage(target_type, target_pid, target_id, damage, element, nil)
    end
  end

  @doc """
  Broadcasts a heal to a player session via PubSub.

  An offline player (no subscriber) is a silent no-op. Mobs are never healed;
  for undead/demon targets use the damage path instead.
  """
  @spec apply_heal(integer(), non_neg_integer(), integer() | nil) :: :ok
  def apply_heal(target_id, amount, source_id \\ nil) do
    PubSub.broadcast(Aesir.PubSub, "player:#{target_id}", {:apply_heal, amount, source_id})
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
         :ok <- validate_attack_with_combatants(attacker, target),
         :ok <- Targeting.validate_enemy(attacker, target) do
      damage =
        amount
        |> DamageShared.apply_element(element, target)
        |> DamageShared.clamp_min_one()

      packet = %SkillDamage{
        skill_id: skill_id,
        level: skill_level,
        src_id: attacker.unit_id,
        target_id: target_id,
        server_tick: ServerTick.now(),
        src_delay: 0,
        dst_delay: 0,
        damage: damage,
        div: 1,
        type: @dmg_splash
      }

      apply_and_broadcast_magic_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        element,
        attacker,
        target,
        packet
      )
    end
  end

  @doc """
  Resolves a unit id to its combatant struct.

  Wraps the internal unit-state lookup so callers outside this module (e.g. ground
  skill-units resolving their caster once per tick) can build a `Combatant` without
  knowing how players and mobs are stored. Returns `{:error, reason}` when the unit
  is gone (logged out, despawned), so the caller can skip cleanly.
  """
  @spec resolve_combatant(integer()) :: {:ok, struct()} | {:error, atom()}
  def resolve_combatant(unit_id) do
    with {:ok, _pid, state, _type} <- get_target_unit_state(unit_id) do
      {:ok, state.__struct__.to_combatant(state)}
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

      packet = %SkillDamage{
        skill_id: skill_id,
        level: skill_level,
        src_id: caster.unit_id,
        target_id: target_id,
        server_tick: ServerTick.now(),
        src_delay: 0,
        dst_delay: dst_delay,
        damage: damage,
        div: packet_divisions,
        type: @dmg_splash
      }

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
    - `:skip_range` - skip only the distance check for a previously validated,
      delayed impact; map, life, and enemy-relation checks still run (default `false`)

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

      packet = %SkillDamage{
        skill_id: skill_id,
        level: skill_level,
        src_id: attacker.unit_id,
        target_id: target_id,
        server_tick: ServerTick.now(),
        src_delay: 0,
        dst_delay: 0,
        damage: total,
        div: hits,
        type: @dmg_splash
      }

      apply_and_broadcast_magic_damage(
        target_type,
        target_pid,
        target_id,
        total,
        element,
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

  defp apply_magic_damage(:skill_unit, manager_pid, target_id, damage, _element, attacker) do
    source = if attacker, do: {attacker.unit_type, attacker.unit_id}
    apply_skill_unit_target_damage(manager_pid, target_id, damage, source)
  end

  defp apply_magic_damage(target_type, target_pid, target_id, damage, element, attacker) do
    hit_info = %{dmg_type: :magic, is_short: false, element: element}
    attacker_id = if attacker, do: attacker.unit_id
    apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker_id)
    :ok
  end

  defp apply_and_broadcast_magic_damage(
         :skill_unit,
         target_pid,
         target_id,
         damage,
         element,
         attacker,
         target,
         packet
       ) do
    with :ok <- apply_magic_damage(:skill_unit, target_pid, target_id, damage, element, attacker) do
      {tx, ty} = target.position
      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)
    end
  end

  defp apply_and_broadcast_magic_damage(
         target_type,
         target_pid,
         target_id,
         damage,
         element,
         attacker,
         target,
         packet
       ) do
    {tx, ty} = target.position
    Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)
    apply_magic_damage(target_type, target_pid, target_id, damage, element, attacker)
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

      packet = %SkillDamage{
        skill_id: skill_id,
        level: skill_level,
        src_id: attacker.unit_id,
        target_id: target_id,
        server_tick: ServerTick.now(),
        src_delay: 0,
        dst_delay: 0,
        damage: damage,
        div: 1,
        type: @dmg_splash
      }

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)
      hit_info = %{dmg_type: :magic, is_short: false, element: element}
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

      packet = %SkillDamage{
        skill_id: skill_id,
        level: skill_level,
        src_id: attacker.unit_id,
        target_id: target_id,
        server_tick: ServerTick.now(),
        src_delay: 0,
        dst_delay: 0,
        damage: damage,
        div: 1,
        type: @dmg_splash
      }

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)
      hit_info = %{dmg_type: :misc, is_short: false, element: element}
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

      packet = %SkillDamage{
        skill_id: skill_id,
        level: skill_level,
        src_id: attacker.unit_id,
        target_id: target_id,
        server_tick: ServerTick.now(),
        src_delay: 0,
        dst_delay: 0,
        damage: damage,
        div: 1,
        type: @dmg_splash
      }

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)
      hit_info = %{dmg_type: :misc, is_short: false, element: element}
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
         :ok <- validate_attack_with_combatants(attacker, target),
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

  Returns the `{unit_type, unit_id}` units that are in the Chebyshev square of
  `radius` cells around `{cx, cy}`, are living enemies of the caster, and are
  alive. Shared by `execute_splash_attack`
  and ground skill-unit behaviours (e.g. Storm Gust) so the target filter — including
  the dead-mob guard — lives in one place.

  The spatial index filters by Manhattan distance (a diamond); we query a Manhattan
  radius of `2 * radius` so the full Chebyshev square is covered, then post-filter.
  """
  @spec splash_targets(String.t(), {integer(), integer()}, non_neg_integer(), integer() | map()) ::
          [{atom(), integer()}]
  def splash_targets(map_name, {cx, cy}, radius, caster) do
    caster = resolve_splash_caster(caster)

    map_name
    |> SpatialIndex.get_all_units_in_range(cx, cy, radius * 2)
    |> Enum.filter(fn target_ref ->
      target_ref != {caster.unit_type, caster.unit_id} and
        offensive_target_in_square?(caster, target_ref, cx, cy, radius)
    end)
  end

  defp offensive_target_in_square?(_caster, {:skill_unit, _target_id}, _cx, _cy, _radius),
    do: false

  defp offensive_target_in_square?(caster, {unit_type, target_id}, cx, cy, radius) do
    case get_target_unit_state(unit_type, target_id) do
      {:ok, _pid, target_state, target_type} ->
        target = target_state.__struct__.to_combatant(target_state)

        ensure_targetable(target_state, target_type) == :ok and
          splash_enemy?(caster, target) and splash_hit?(target_state, cx, cy, radius)

      _ ->
        false
    end
  end

  defp resolve_splash_caster(%{unit_type: _unit_type} = caster), do: caster

  defp resolve_splash_caster(caster_id) do
    case UnitRegistry.get_unit(:player, caster_id) do
      {:ok, {module, state, _pid}} -> module.to_combatant(state)
      _ -> %{unit_type: :player, unit_id: caster_id, relation_unavailable: true}
    end
  end

  # If the caster's relation snapshot is unavailable, retain the old safe PvE
  # fallback: mobs remain targetable, but players are not.
  defp splash_enemy?(%{relation_unavailable: true}, %{unit_type: :player}), do: false
  defp splash_enemy?(caster, target), do: Targeting.validate_enemy(caster, target) == :ok

  # Keeps the square (Chebyshev) AoE shape and drops dead mobs awaiting despawn.
  defp splash_hit?(%{hp: hp}, _x, _y, _radius) when hp <= 0, do: false

  defp splash_hit?(%{x: tx, y: ty}, x, y, radius),
    do: Geometry.chebyshev_distance(x, y, tx, ty) <= radius

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
        element: :neutral
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

  # Routes damage to the owning session by unit type, keeping the damage paths
  # free of concrete session-module knowledge. Targets with positive damage
  # first run the hit through the pre-damage status absorption hook (Kyrie, Safety
  # Wall, Energy Coat) so statuses can reduce or block it before HP is reduced,
  # regardless of whether the defender is a player or a mob.
  defp apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker_id) do
    final_damage = absorb_unit_damage(target_type, target_id, damage, hit_info)
    unit_session(target_type).apply_damage(target_pid, final_damage, attacker_id)
  end

  defp absorb_unit_damage(target_type, target_id, damage, hit_info) when damage > 0 do
    StatusInterpreter.absorb_damage(target_type, target_id, damage, hit_info)
  end

  defp absorb_unit_damage(_target_type, _target_id, damage, _hit_info), do: damage

  defp unit_session(:mob), do: MobSession
  defp unit_session(:player), do: PlayerSession

  @doc """
  Knocks a unit back away from `{from_x, from_y}`, collision-aware.

  Walks the unit outward one cell at a time (8-dir, away from the source through
  its current cell) up to `distance` cells, stopping at the last walkable cell
  before a wall (rAthena `unit_blown`). Updates the unit state, the spatial index
  and the registry, then broadcasts `Knockback` to nearby players so they slide
  the unit to its landing cell.

  Returns `:ok` for skill units, `{:ok, {dst_x, dst_y}}` with the final cell
  (unchanged if it could not move), or `{:error, reason}` if the unit or its
  map could not be resolved.
  """
  @spec knockback(atom(), integer(), integer(), integer(), non_neg_integer()) ::
          :ok | {:ok, {integer(), integer()}} | {:error, atom()}
  def knockback(:skill_unit, _unit_id, _from_x, _from_y, _distance), do: :ok

  def knockback(unit_type, unit_id, from_x, from_y, distance) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         {:ok, _map} <- MapCache.get(map_name) do
      {dx, dy} = {sign(x - from_x), sign(y - from_y)}
      {dst_x, dst_y} = blow_path(map_name, x, y, dx, dy, distance)

      if {dst_x, dst_y} != {x, y} do
        move_unit(unit_type, unit_id, dst_x, dst_y, map_name)
        broadcast_blownback(unit_id, dst_x, dst_y, map_name)
      end

      {:ok, {dst_x, dst_y}}
    end
  end

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0

  # No direction (unit on top of source): nowhere to blow.
  defp blow_path(_map_name, x, y, 0, 0, _distance), do: {x, y}

  # Step outward, keeping the last walkable cell reached.
  defp blow_path(map_name, x, y, dx, dy, distance) do
    Enum.reduce_while(1..distance//1, {x, y}, fn _step, {cx, cy} ->
      {nx, ny} = {cx + dx, cy + dy}

      if Cell.traversable?(map_name, nx, ny) do
        {:cont, {nx, ny}}
      else
        {:halt, {cx, cy}}
      end
    end)
  end

  # Routes the landing-cell update through the owning session so it is the single
  # writer: the session updates its live `game_state` (position + stop walking)
  # and re-syncs the spatial index/registry/dirty set via `Movement.set_position`,
  # which prevents a knocked-back moving unit's own next tick from overwriting the
  # blow. Falls back to a direct write when the owning process can't be resolved.
  defp move_unit(unit_type, unit_id, x, y, map_name) do
    case owning_pid(unit_type, unit_id) do
      {:ok, pid} -> GenServer.cast(pid, {:knocked_back, x, y})
      :error -> move_unit_direct(unit_type, unit_id, x, y, map_name)
    end
  end

  defp owning_pid(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> {:ok, pid}
      _ -> :error
    end
  end

  defp move_unit_direct(unit_type, unit_id, x, y, map_name) do
    with {:ok, {module, state, _pid}} <- UnitRegistry.get_unit(unit_type, unit_id) do
      UnitRegistry.update_unit_state(unit_type, unit_id, module.update_position(state, x, y))
    end

    SpatialIndex.update_unit_position(unit_type, unit_id, x, y, map_name)
    Movement.mark_dirty(map_name, unit_type, unit_id, 0)
  end

  defp broadcast_blownback(unit_id, dst_x, dst_y, map_name) do
    packet = %Knockback{unit_id: unit_id, dst_x: dst_x, dst_y: dst_y}
    Broadcast.to_in_range(map_name, dst_x, dst_y, Config.view_range(), packet)
  end

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
    PlayerSession.apply_damage(target_pid, damage, attacker_combatant.unit_id)
  end

  # New function that returns actual unit states instead of maps
  defp get_target_unit_state(:mob, target_id), do: get_mob_unit_state(target_id)
  defp get_target_unit_state(:player, target_id), do: get_player_unit_state(target_id)
  defp get_target_unit_state(:skill_unit, target_id), do: get_skill_unit_state(target_id)

  defp get_target_unit_state(target_id) do
    if SkillUnitId.skill_unit?(target_id) do
      get_skill_unit_state(target_id)
    else
      case get_player_unit_state(target_id) do
        {:ok, pid, player_state, :player} ->
          {:ok, pid, player_state, :player}

        {:error, :target_not_found} ->
          get_standard_mob_unit_state(target_id)
      end
    end
  end

  defp get_standard_mob_unit_state(target_id) do
    case get_mob_unit_state(target_id) do
      {:error, :not_found} -> {:error, :target_not_found}
      result -> result
    end
  end

  defp get_skill_unit_state(target_id) do
    with {:ok, {CombatTarget, _cell, manager_pid}} when is_pid(manager_pid) <-
           UnitRegistry.get_unit(:skill_unit, target_id),
         {:ok, cell} <- SkillUnitManager.targetable_cell(manager_pid, target_id) do
      {:ok, manager_pid, cell, :skill_unit}
    else
      _ -> {:error, :target_not_found}
    end
  end

  defp get_mob_unit_state(target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, mob_state, pid}} when is_pid(pid) ->
        # Get the current position from SpatialIndex for consistency
        updated_mob_state =
          case SpatialIndex.get_unit_position(:mob, target_id) do
            {:ok, {x, y, _map}} ->
              %{mob_state | x: x, y: y}

            _ ->
              mob_state
          end

        {:ok, pid, updated_mob_state, :mob}

      {:error, :not_found} ->
        Logger.warning("Mob #{target_id} not found in registry")
        {:error, :not_found}

      {:ok, {_module, _state, nil}} ->
        Logger.warning("Mob #{target_id} found but has no pid")
        {:error, :target_no_pid}
    end
  end

  defp get_player_unit_state(target_id) do
    case UnitRegistry.get_player_pid(target_id) do
      {:ok, pid} ->
        stats = PlayerSession.get_current_stats(pid)
        session_state = PlayerSession.get_state(pid)
        # Extract the game_state which is the actual PlayerState
        player_state = session_state.game_state
        # Update player state with current stats for combat
        player_state = %{player_state | stats: stats}
        {:ok, pid, player_state, :player}

      {:error, :not_found} ->
        Logger.warning("Target #{target_id} not found in registry")
        {:error, :target_not_found}
    end
  end

  # A target that has died (or, for players, transitioned to :dead) is not a
  # valid target. The melee path resolves the full unit state, so this is the
  # authoritative gate; `MobSession` independently drops damage to dead mobs.
  defp ensure_targetable(%{is_dead: true}, :mob), do: {:error, :target_dead}
  defp ensure_targetable(%{hp: hp}, :mob) when hp <= 0, do: {:error, :target_dead}
  defp ensure_targetable(_target_state, :mob), do: :ok
  defp ensure_targetable(%{action_state: :dead}, :player), do: {:error, :target_dead}
  defp ensure_targetable(_target_state, :player), do: :ok
  defp ensure_targetable(%{hp: hp}, :skill_unit) when hp > 0, do: :ok
  defp ensure_targetable(_target_state, :skill_unit), do: {:error, :target_dead}

  # New combatant-based functions
  defp validate_attack_with_combatants(attacker_combatant, target_combatant, opts \\ []) do
    with :ok <- validate_same_map(attacker_combatant, target_combatant),
         :ok <- validate_attack_distance(attacker_combatant, target_combatant, opts) do
      validate_projectile_path(attacker_combatant, target_combatant, opts)
    end
  end

  defp validate_same_map(%{map_name: map_name}, %{map_name: map_name}), do: :ok
  defp validate_same_map(_attacker, _target), do: {:error, :different_map}

  defp validate_attack_distance(attacker, target, opts) do
    if Keyword.get(opts, :skip_range, false),
      do: :ok,
      else: validate_attack_range(attacker, target)
  end

  defp validate_projectile_path(attacker, target, opts) do
    if Keyword.get(opts, :projectile?, false) and attacker.attack_range > 1 do
      validate_projectile_line(attacker, target)
    else
      :ok
    end
  end

  defp validate_projectile_line(attacker, target) do
    if LineOfSight.clear?(attacker.map_name, attacker.position, target.position) do
      :ok
    else
      {:error, :projectile_blocked}
    end
  end

  defp validate_attack_range(attacker_combatant, target_combatant) do
    attack_range = attacker_combatant.attack_range
    {attacker_x, attacker_y} = attacker_combatant.position
    {target_x, target_y} = target_combatant.position

    distance = Geometry.chebyshev_distance(attacker_x, attacker_y, target_x, target_y)

    if distance <= attack_range do
      :ok
    else
      Logger.debug(
        "Attack failed: target out of range (distance: #{distance}, max: #{attack_range})"
      )

      {:error, :target_out_of_range}
    end
  end

  defp validate_mob_attack_with_combatants(attacker_combatant, target_combatant) do
    # Validate mob attack range using combatant positions
    # Get attack range from the mob data via the combatant
    attack_range = attacker_combatant.attack_range
    {attacker_x, attacker_y} = attacker_combatant.position
    {target_x, target_y} = target_combatant.position

    distance = Geometry.chebyshev_distance(attacker_x, attacker_y, target_x, target_y)

    if distance <= attack_range do
      :ok
    else
      Logger.debug(
        "Mob attack failed: target out of range (distance: #{distance}, max: #{attack_range})"
      )

      {:error, :target_out_of_range}
    end
  end

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

  # Broadcasts a combat packet to players near the target. Works for both
  # combatant structs and map-based target stats (both carry position/map_name).
  defp broadcast_to_nearby_players(target, packet) do
    {x, y} = target.position
    Broadcast.to_in_range(target.map_name, x, y, Config.view_range(), packet)
  end
end
