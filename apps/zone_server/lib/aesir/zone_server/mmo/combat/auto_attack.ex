defmodule Aesir.ZoneServer.Mmo.Combat.AutoAttack do
  @moduledoc """
  Basic (auto) attack execution for players and mobs.

  Runs the full swing: hit/miss/perfect-dodge roll, damage calculation,
  multi-hit passives, equipment-break rolls, attacker-side `on_dealt_damage`
  status procs, HP drain, and the equipment-granted splash around the target.
  `execute_attack/3` runs inside the attacker's `PlayerSession`, so
  self-directed effects (breaks, auto-casts, drain heals) are messages to
  `self()`.
  """

  require Logger

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.EquipVanish
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.HpDrain
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.SpDrain
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Blade Stop (MO_BLADESTOP) skill id, read from a caught player attacker's
  # learned skills so their own Root record carries their own level; a monster
  # attacker hardcodes 5, matching the Renewal source.
  @bladestop_skill_id 269
  @mob_root_level 5

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
  @type combo_result ::
          {:ok, {:combo, atom(), {atom(), non_neg_integer()}, non_neg_integer()}}

  @type attack_result :: :ok | :intercepted | combo_result() | {:error, atom()}

  @spec execute_attack(map(), map(), integer() | Ref.t()) :: attack_result()
  def execute_attack(stats, player_state, target_id) do
    {result, _player_state} =
      execute_attack(stats, player_state, target_id, &recalculate_player_state/1)

    result
  end

  @doc "Executes a player attack and returns the post-commit player state to its owner session."
  @spec execute_attack(map(), map(), integer() | Ref.t(), (map() -> map())) ::
          {attack_result(), map()}
  def execute_attack(stats, player_state, target_id, recalculate) do
    player_state = %{player_state | stats: stats}
    validation_combatant = player_state.__struct__.to_combatant(player_state)

    case validate_player_attack(validation_combatant, target_id) do
      {:ok, target_pid, target_state, target_type, target_combatant} ->
        player_state =
          commit_normal_attack(player_state, validation_combatant.unit_id, recalculate)

        attacker = player_state.__struct__.to_combatant(player_state)

        result =
          resolve_player_attack_or_intercept(
            player_state,
            target_state,
            attacker,
            target_combatant,
            target_pid,
            target_type,
            target_combatant.unit_id
          )

        case result do
          {:snatcher, updated_player_state} -> {:ok, updated_player_state}
          result -> {result, player_state}
        end

      error ->
        {error, player_state}
    end
  end

  defp validate_player_attack(attacker, target_id) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate(attacker, target, projectile?: true),
         :ok <- validate_player_target(attacker, target, target_type) do
      {:ok, target_pid, target_state, target_type, target}
    end
  end

  defp commit_normal_attack(player_state, player_id, recalculate) do
    case StatusInterpreter.on_committed_action(:player, player_id, :normal_attack) do
      :changed -> recalculate.(player_state)
      :unchanged -> player_state
    end
  end

  defp recalculate_player_state(%{character_id: character_id, stats: stats} = player_state) do
    %{player_state | stats: PlayerStats.calculate_stats(stats, character_id)}
  end

  defp recalculate_player_state(player_state), do: player_state

  defp resolve_player_attack_or_intercept(
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id
       ) do
    case before_weapon_hit(
           :player,
           attacker,
           target,
           target_type,
           target_id,
           attacker_root_level(player_state)
         ) do
      :continue ->
        resolve_player_attack_or_replacement(
          player_state,
          target_state,
          attacker,
          target,
          target_pid,
          target_type,
          target_id
        )

      {:intercept, result} ->
        broadcast_guard_feedback(result, attacker, target)
        :intercepted
    end
  end

  defp resolve_player_attack_or_replacement(
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id
       ) do
    case Passives.attack_replacement(player_state) do
      :normal ->
        modifier = normal_attack_modifier(:player, attacker, target_type, target_id)

        calculate_player_normal_attack(
          player_state,
          target_state,
          attacker,
          target,
          target_pid,
          target_type,
          target_id,
          modifier
        )

      {:skill_attack, opts, next_stage} ->
        with :ok <-
               resolve_attack_replacement(
                 player_state,
                 attacker,
                 target,
                 target_id,
                 opts
               ) do
          {:ok, {:combo, next_stage, {target_type, target_id}, max(attacker.attack_delay_ms, 1)}}
        end
    end
  end

  defp calculate_player_normal_attack(
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id,
         modifier
       )
       when target_type in [:homunculus, :skill_unit] do
    with {:ok, combat_result} <- check_hit_and_calculate_damage(attacker, target) do
      combat_result =
        combat_result
        |> apply_poison_rider_on_hit(
          modifier,
          {:player, attacker.unit_id},
          {target_type, target_id}
        )
        |> apply_damage_modifier(modifier)

      resolve_player_attack(
        combat_result,
        player_state,
        target_state,
        attacker,
        target,
        target_pid,
        target_type,
        target_id
      )
    end
  end

  defp calculate_player_normal_attack(
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id,
         modifier
       ) do
    with {:ok, swing} <- HandedAttack.calculate(player_state, attacker, target) do
      swing =
        swing
        |> apply_poison_rider_on_hit(
          modifier,
          {:player, attacker.unit_id},
          {target_type, target_id}
        )
        |> apply_damage_modifier(modifier)

      resolve_player_weapon_swing(
        swing,
        player_state,
        target_state,
        attacker,
        target,
        target_pid,
        target_type,
        target_id
      )
    end
  end

  defp resolve_attack_replacement(player_state, attacker, target, target_id, opts) do
    case weapon_skill_hit_result(attacker, target) do
      :hit ->
        SkillAttack.execute_skill_attack(player_state, target_id, opts)

      :miss ->
        damage_result = %{damage: 0, is_critical: false}

        packet =
          PacketFactory.build_skill_damage_packet(
            attacker,
            target,
            Keyword.fetch!(opts, :skill_id),
            Keyword.fetch!(opts, :skill_level),
            damage_result,
            div: Keyword.get(opts, :display_hit_count, 1)
          )

        DamageApplication.broadcast_nearby(target, packet)
    end

    :ok
  end

  defp weapon_skill_hit_result(attacker, target) do
    attacker_stats = %{
      hit: attacker.combat_stats.hit,
      char_id: attacker.unit_id,
      perfect_hit: EquipmentBonuses.perfect_hit_rate(attacker)
    }

    target_stats = %{
      flee: target.combat_stats.flee,
      perfect_dodge: 0,
      unit_id: target.unit_id
    }

    case HitCalculations.calculate_hit_result(attacker_stats, target_stats) do
      :hit -> :hit
      _ -> :miss
    end
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
  @spec execute_mob_attack(map(), integer() | Ref.t()) ::
          :ok | :intercepted | {:error, atom()}
  def execute_mob_attack(mob_state, target) do
    attacker_combatant = mob_state.__struct__.to_combatant(mob_state)
    target = typed_mob_target(target)

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target),
         true <- target_type in [:player, :homunculus],
         :ok <- ensure_mob_targetable(target_state, target_type),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate_mob_attack(attacker_combatant, target_combatant) do
      resolve_mob_attack_or_intercept(
        attacker_combatant,
        target_combatant,
        target_pid,
        target_type,
        target_combatant.unit_id
      )
    else
      false -> {:error, :invalid_target}
      error -> error
    end
  end

  @doc "Executes one collision-safe Homunculus basic attack against a typed target."
  @spec execute_homunculus_attack(struct(), Ref.t()) ::
          DamageApplication.delivery_result() | {:error, atom()}
  def execute_homunculus_attack(homunculus_state, target_ref) do
    attacker = homunculus_state.__struct__.to_combatant(homunculus_state)

    with true <- Ref.valid?(target_ref),
         {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         target_hp <- target_state.__struct__.get_stats(target_state).hp,
         :ok <- AttackValidator.validate(attacker, target, projectile?: true),
         :ok <- validate_homunculus_target(attacker, target, target_type),
         modifier <- normal_attack_modifier(:homunculus, attacker, target_type, target.unit_id),
         {:ok, combat_result} <- check_hit_and_calculate_damage(attacker, target) do
      combat_result =
        combat_result
        |> apply_poison_rider_on_hit(
          modifier,
          {:homunculus, attacker.unit_id},
          {target_type, target.unit_id}
        )
        |> apply_damage_modifier(modifier)

      resolve_homunculus_attack(
        combat_result,
        attacker,
        target,
        target_pid,
        target_type,
        target_hp
      )
    else
      false -> {:error, :invalid_target}
      error -> error
    end
  end

  defp resolve_mob_attack_or_intercept(attacker, target, target_pid, target_type, target_id) do
    case before_weapon_hit(:mob, attacker, target, target_type, target_id, @mob_root_level) do
      {:intercept, result} ->
        broadcast_guard_feedback(result, attacker, target)
        :intercepted

      :continue ->
        modifier = normal_attack_modifier(:mob, attacker, target_type, target_id)

        with {:ok, combat_result} <- check_hit_and_calculate_damage(attacker, target) do
          combat_result =
            combat_result
            |> apply_poison_rider_on_hit(
              modifier,
              {:mob, attacker.unit_id},
              {target_type, target_id}
            )
            |> apply_damage_modifier(modifier)

          resolve_mob_attack(
            combat_result,
            attacker,
            target,
            target_pid,
            target_type,
            target_id
          )
        end
    end
  end

  defp resolve_mob_attack(
         combat_result,
         attacker_combatant,
         target_combatant,
         target_pid,
         target_type,
         target_id
       ) do
    case combat_result do
      {:miss} ->
        Logger.debug(
          "Combat: Mob #{attacker_combatant.unit_id} attack missed player #{target_id}"
        )

        miss_packet = PacketFactory.build_miss_packet(attacker_combatant, target_combatant)
        DamageApplication.broadcast_nearby(target_combatant, miss_packet)

      {:perfect_dodge} ->
        Logger.debug(
          "Combat: Mob #{attacker_combatant.unit_id} attack perfect dodged by player #{target_id}"
        )

        dodge_packet =
          PacketFactory.build_perfect_dodge_packet(attacker_combatant, target_combatant)

        DamageApplication.broadcast_nearby(target_combatant, dodge_packet)

      {:hit, damage_result} ->
        handle_mob_attack_hit(
          damage_result,
          attacker_combatant,
          target_combatant,
          target_pid,
          target_type,
          target_id
        )
    end

    :ok
  end

  # A shield block (Guard) lands as a zero-damage hit, so the attacker's client
  # still sees the swing connect. Other interceptions (Auto Counter, Blade Stop)
  # own their own feedback and stay silent here.
  defp broadcast_guard_feedback(:blocked, attacker, target) do
    DamageApplication.broadcast_nearby(target, PacketFactory.build_guard_packet(attacker, target))
  end

  defp broadcast_guard_feedback(_result, _attacker, _target), do: :ok

  defp before_weapon_hit(
         _attacker_type,
         _attacker,
         _target,
         :skill_unit,
         _target_id,
         _root_level
       ),
       do: :continue

  defp before_weapon_hit(
         attacker_type,
         attacker,
         target,
         target_type,
         target_id,
         attacker_root_level
       ) do
    StatusInterpreter.before_weapon_hit(target_type, target_id, %{
      attacker: {attacker_type, attacker.unit_id},
      target: {target_type, target.unit_id},
      attacker_boss?: attacker.class == :boss,
      attacker_root_level: attacker_root_level,
      attacker_position: attacker.position,
      attacker_short?: attacker.attack_range <= 3,
      distance: cell_distance(attacker, target),
      basic_attack?: true,
      element: primary_attack_element(attacker_type, attacker)
    })
  end

  # A caught player attacker's own Blade Stop level (0 when unlearned) drives their
  # Root record's follow-up gate, read from the real player progression's
  # `learned_skills` map. The fallback fires only when the caster state carries no
  # such map (a mob combatant reused as a caster, or a bare test fixture), never
  # crashing the swing; a real player always hits the first clause.
  defp attacker_root_level(%{stats: %{progression: %{learned_skills: learned}}})
       when is_map(learned),
       do: Learned.learned_level(learned, @bladestop_skill_id)

  defp attacker_root_level(_state), do: 0

  defp primary_attack_element(:mob, %{element: {element, _level}}), do: element
  defp primary_attack_element(_attacker_type, attacker), do: attacker.weapon.element

  defp normal_attack_modifier(attacker_type, attacker, target_type, target_id) do
    attack_info = %{
      target: {target_type, target_id},
      element: primary_attack_element(attacker_type, attacker)
    }

    StatusInterpreter.before_normal_attack(attacker_type, attacker.unit_id, attack_info)
  end

  defp apply_poison_rider_on_hit(
         {:hit, _damage_result} = result,
         modifier,
         source,
         target
       ) do
    apply_poison_rider(modifier, source, target)
    result
  end

  defp apply_poison_rider_on_hit(
         %HandedAttack{outcome: outcome} = result,
         modifier,
         source,
         target
       )
       when outcome in [:hit, :critical] do
    apply_poison_rider(modifier, source, target)
    result
  end

  defp apply_poison_rider_on_hit(result, _modifier, _source, _target), do: result

  defp apply_poison_rider(%{poison: poison}, source, {target_type, target_id})
       when target_type != :skill_unit do
    if :rand.uniform(100) <= poison.chance do
      {source_type, source_id} = source

      case StatusInterpreter.apply_status(target_type, target_id, :sc_poison,
             caster_id: source_id,
             source_type: source_type,
             duration: poison.duration,
             val1: poison.level
           ) do
        :ok ->
          :ok

        {:error, reason}
        when reason in [:immune, :boss_immune, :prevented, :conflict, :resisted, :target_dead] ->
          :ok

        {:error, reason} ->
          raise "ordinary-swing Poison rider failed: #{inspect(reason)}"
      end
    end

    :ok
  end

  defp apply_poison_rider(_modifier, _source, _target), do: :ok

  defp apply_damage_modifier(%HandedAttack{} = swing, %{damage_rate: rate}) do
    primary = scale_damage_result(swing.primary, rate)
    secondary = if swing.secondary, do: scale_damage_result(swing.secondary, rate)

    %{
      swing
      | primary: primary,
        secondary: secondary,
        raw_total: primary.damage + if(secondary, do: secondary.damage, else: 0)
    }
  end

  defp apply_damage_modifier({:hit, result}, %{damage_rate: rate}),
    do: {:hit, scale_damage_result(result, rate)}

  defp apply_damage_modifier(result, _modifier), do: result

  defp scale_damage_result(result, rate),
    do: %{result | damage: div(result.damage * (100 + rate), 100)}

  # Chebyshev cell distance between the two combatants, the Renewal metric Root
  # uses to gate monster attackers. Positions ride both combatants on a real
  # swing; the weapon-range proxy is only a fallback for a combatant built
  # without a position.
  defp cell_distance(%{position: {ax, ay}}, %{position: {tx, ty}}),
    do: Geometry.chebyshev_distance(ax, ay, tx, ty)

  defp cell_distance(attacker, _target), do: attacker.attack_range

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

    DamageApplication.broadcast_nearby(target, PacketFactory.build_miss_packet(attacker, target))

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

    DamageApplication.broadcast_nearby(
      target,
      PacketFactory.build_perfect_dodge_packet(attacker, target)
    )

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
    attack_flag = normal_attack_flag(attacker)

    if damage_result.damage > 1,
      do: EquipVanish.after_hit(attacker, target, target_pid, attack_flag)

    with :ok <-
           handle_player_attack_hit(
             damage_result,
             attacker,
             target,
             target_pid,
             target_type,
             target_id,
             1
           ) do
      dispatch_normal_hit_passives(player_state, target_type, target_id, target)
      roll_equipment_breaks(player_state, target_state, target_type, target_id, target_pid)

      dispatch_dealt_damage(
        attacker,
        target_type,
        target_id,
        damage_result.damage,
        attacker.weapon.element
      )

      OnHitEffects.after_hit(attacker, target, damage_result,
        attack_flag: normal_attack_flag(attacker)
      )

      dispatch_equip_autocasts(attacker, target, target_pid, normal_attack_flag(attacker))

      drain_hp(attacker, damage_result.damage)
      drain_sp(attacker, damage_result.damage)
      splash_attack(attacker, target)
      :ok
    end
  end

  defp resolve_player_weapon_swing(
         %HandedAttack{outcome: :miss},
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id
       ) do
    resolve_player_attack(
      {:miss},
      player_state,
      target_state,
      attacker,
      target,
      target_pid,
      target_type,
      target_id
    )
  end

  defp resolve_player_weapon_swing(
         %HandedAttack{outcome: :perfect_dodge},
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id
       ) do
    resolve_player_attack(
      {:perfect_dodge},
      player_state,
      target_state,
      attacker,
      target,
      target_pid,
      target_type,
      target_id
    )
  end

  defp resolve_player_weapon_swing(
         %HandedAttack{} = swing,
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id
       ) do
    attack_flag = normal_attack_flag(attacker)
    if swing.raw_total > 1, do: EquipVanish.after_hit(attacker, target, target_pid, attack_flag)
    override = EquipVanish.normal_attack_override(attacker, target)
    swing = apply_vanish_override(swing, override)

    hit_info = %{
      dmg_type: :physical,
      is_short: true,
      element: swing.primary_element,
      skill_id: nil,
      skill_level: nil,
      from_caster?: true,
      basic_attack?: true
    }

    source = player_damage_source(target_type, attacker.unit_id)

    {settled, delivery} =
      case override do
        {:sp, _amount} ->
          {swing, :ok}

        _other ->
          DamageApplication.apply_weapon_swing(
            target_type,
            target_pid,
            target_id,
            swing,
            hit_info,
            source
          )
      end

    with :ok <- delivery do
      DamageApplication.broadcast_nearby(
        target,
        PacketFactory.build_weapon_swing_packet(attacker, target, settled,
          is_sp_damage: match?({:sp, _amount}, override)
        )
      )

      case override do
        {:sp, amount} ->
          Resource.drain_sp({target_type, target_id}, amount)
          {:snatcher, player_state}

        _other ->
          damage = settled_damage(settled)
          damage_result = %{damage: damage, is_critical: settled.outcome == :critical}
          updated_player_state = maybe_snatch(player_state, target_type, target_id)

          dispatch_normal_hit_passives(player_state, target_type, target_id, target)
          roll_equipment_breaks(player_state, target_state, target_type, target_id, target_pid)
          dispatch_dealt_damage(attacker, target_type, target_id, damage, settled.primary_element)

          OnHitEffects.after_hit(attacker, target, damage_result, attack_flag: attack_flag)
          dispatch_equip_autocasts(attacker, target, target_pid, attack_flag)

          drain_hp(attacker, damage)
          drain_sp(attacker, damage)
          splash_attack(attacker, target)
          {:snatcher, updated_player_state}
      end
    end
  end

  defp maybe_snatch(player_state, :mob, target_id) do
    chance = Passives.steal_proc(player_state)

    if chance > 0 and :rand.uniform(1_000) <= chance do
      snatch(player_state, target_id)
    else
      player_state
    end
  end

  defp maybe_snatch(player_state, _target_type, _target_id), do: player_state

  defp snatch(player_state, target_id) do
    caster_dex = PlayerStats.get_effective_stat(player_state.stats, :dex)
    tf_steal_level = Learned.learned_level(player_state.stats.progression.learned_skills, 50)

    with {:ok, {_module, _state, mob_pid}} <- UnitRegistry.get_unit(:mob, target_id),
         {:ok, item_id} <- MobSession.attempt_steal(mob_pid, caster_dex, tf_steal_level),
         {:ok, item_def} <- ItemManagement.get_item_by_id(item_id),
         {:ok, inventory, change} <-
           InventoryOps.add(
             player_state.character_id,
             player_state.inventory,
             player_state.stats,
             item_def,
             1
           ) do
      %{
        player_state
        | inventory: inventory,
          pending_inventory_notify: player_state.pending_inventory_notify ++ [change]
      }
    else
      _ -> player_state
    end
  end

  # The confirmed-ordinary-hit passive seam: fires exactly once per successful
  # primary swing, right after the hit has landed. Skill-unit targets are
  # excluded (not living targets a passive can act on); misses, perfect dodge,
  # attack replacements and splash secondaries never reach this point. The
  # target position is read from the pre-hit combatant snapshot, so a target
  # killed or despawned by the swing cannot erase it.
  defp dispatch_normal_hit_passives(_player_state, :skill_unit, _target_id, _target), do: :ok

  defp dispatch_normal_hit_passives(player_state, target_type, target_id, target) do
    Passives.after_normal_hit(player_state, %{
      target_type: target_type,
      target_id: target_id,
      position: target.position
    })
  end

  # Classifies a swing for the trigger-flagged equipment bonuses: always a
  # weapon attack of normal (non-skill) origin, melee or ranged by the same
  # attack-range rule that sets `is_short` on the delivered hit.
  @spec normal_attack_flag(Combatant.t()) :: BattleFlags.flag()
  defp normal_attack_flag(attacker) do
    range = if Map.get(attacker, :attack_range, 1) <= 3, do: :short, else: :long
    BattleFlags.build(:weapon, range, false)
  end

  # Rolls both sides' equipment autocasts for a landed swing.
  #
  # The attacker's own procs are cast to `self()`, exactly like the
  # `SC_AUTOSPELL` bolt: this runs inside the attacker's session, so the cast
  # lands after the current message on state the session already committed. The
  # defender's when-hit procs are handed to the defender's session instead, so
  # each side's skills are cast by its own single writer. A mob defender carries
  # no equipment and produces nothing.
  @spec dispatch_equip_autocasts(Combatant.t(), Combatant.t(), pid() | nil, BattleFlags.flag()) ::
          :ok
  defp dispatch_equip_autocasts(attacker, target, target_pid, attack_flag) do
    attacker
    |> EquipAutocast.on_attack(target, attack_flag)
    |> Enum.each(&send_auto_cast(self(), &1))

    target
    |> EquipAutocast.when_hit(attacker, attack_flag)
    |> Enum.each(&send_auto_cast(target_pid, &1))
  end

  @spec send_auto_cast(pid() | nil, EquipAutocast.proc()) :: :ok
  defp send_auto_cast(nil, _proc), do: :ok

  defp send_auto_cast(pid, {:auto_cast, skill_id, level, target}) do
    GenServer.cast(pid, {:skill, {:proc_cast, skill_id, level, target}})
  end

  # Recovers HP from the damage a landed swing dealt, when the attacker's
  # equipment carries the drain bonus. Rolled once per swing over the swing's
  # total damage (multi-hit included), never per delivered hit, so a multi-hit
  # proc does not multiply the number of rolls.
  #
  # The heal is a broadcast to the attacker's own session rather than a direct
  # state write: `execute_attack/3` runs inside that session, so it lands as an
  # ordinary message the single writer applies after the current one.
  defp drain_hp(attacker, damage) do
    case HpDrain.roll(attacker, damage) do
      0 -> :ok
      heal -> DamageApplication.apply_heal(:player, attacker.unit_id, heal, attacker.unit_id)
    end
  end

  defp drain_sp(attacker, damage) do
    case SpDrain.roll(attacker, damage) do
      0 -> :ok
      sp -> DamageApplication.apply_sp_heal(:player, attacker.unit_id, sp)
    end
  end

  # Extends a landed normal attack to every other valid enemy within the
  # attacker's equipment-granted splash radius, centered on the primary target's
  # cell. Target selection is the same primitive the splash skills use, so the
  # hostility, targetability and dead-unit rules stay in one place.
  #
  # Each splashed target rolls its own hit/miss and damage — it is a separate
  # swing landing on a different defender — and receives exactly one hit: the
  # multi-hit proc, the break roll and the attacker's on-dealt-damage procs all
  # belong to the primary swing and are not repeated here. The primary target is
  # excluded, so it keeps taking exactly the hit already dealt above.
  defp splash_attack(attacker, target) do
    case EquipmentBonuses.splash_range(attacker) do
      0 ->
        :ok

      radius ->
        attacker.map_name
        |> SplashTargets.select(target.position, radius, attacker)
        |> Enum.reject(&(&1 == {target.unit_type, target.unit_id}))
        |> Enum.each(&splash_hit(attacker, &1))
    end
  end

  defp splash_hit(attacker, {_unit_type, target_id} = target_ref) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_ref),
         splash_target <- target_state.__struct__.to_combatant(target_state),
         {:ok, {:hit, damage_result}} <-
           check_hit_and_calculate_damage(attacker, splash_target) do
      handle_player_attack_hit(
        damage_result,
        attacker,
        splash_target,
        target_pid,
        target_type,
        target_id,
        1
      )
    end

    :ok
  end

  # Rolls equipment breaks once per confirmed weapon hit (never once per
  # multi-hit) and dispatches each decision to the owning session. `execute_attack`
  # runs inside the attacker's `PlayerSession`, so a `:self` break is a cast to
  # `self()`; a `:target` break goes to `target_pid`. The resolver only emits
  # `:target` decisions for player victims (mob "equipment" never breaks in
  # Renewal), so mob targets receive nothing.
  #
  defp roll_equipment_breaks(player_state, target_state, target_type, target_id, target_pid) do
    target_type
    |> break_target(target_id, target_state)
    |> maybe_roll(player_state, target_pid)
  end

  defp break_target(:player, target_id, target_state),
    do: {:player, target_id, target_state.stats}

  defp break_target(target_type, _target_id, target_state), do: {target_type, target_state}

  defp maybe_roll(target, player_state, target_pid) do
    player_state.stats
    |> EquipBreak.resolve(target)
    |> Enum.each(&dispatch_break(&1, target_pid))
  end

  defp dispatch_break({:self, slot}, _target_pid),
    do: PlayerSession.break_equip(self(), break_slot(slot))

  defp dispatch_break({:target, slot}, target_pid),
    do: PlayerSession.break_equip(target_pid, break_slot(slot))

  defp break_slot(:weapon), do: :right_hand
  # Left hand may hold a two-handed weapon's composite bit; the first shield-break
  # caller must guard on the item being armor-typed before breaking this slot.
  defp break_slot(:shield), do: :left_hand
  defp break_slot(:armor), do: :armor
  defp break_slot(:helm), do: :head_top

  # Fires the attacker's `on_dealt_damage` statuses once per confirmed weapon
  # swing (never per multi-hit), the attacker-side counterpart of the victim's
  # `on_damage`. Sited after the damage casts, the attack broadcast and the
  # break roll, so every effect of the triggering hit is already queued on the
  # victim's mailbox ahead of anything an auto-cast sends it.
  #
  # Skill units are excluded: they are not living targets and hold no state a
  # proc could act on (rAthena procs autospell against `bl` units only).
  defp dispatch_dealt_damage(_attacker, :skill_unit, _target_id, _damage, _element), do: :ok

  defp dispatch_dealt_damage(attacker, target_type, target_id, damage, element) do
    hit_info = %{
      target: {target_type, target_id},
      damage: damage,
      element: element
    }

    :player
    |> StatusInterpreter.on_dealt_damage(attacker.unit_id, hit_info)
    |> Enum.each(&drain_auto_cast/1)
  end

  # `execute_attack/3` runs inside the attacker's own `PlayerSession`, so the
  # auto-cast is a cast to `self()` (like a `:self` equipment break): it runs
  # after the current message finishes, on state the session has already
  # committed. `SC_AUTOSPELL` is the only producer today; the session's
  # `{:skill, {:auto_cast, ...}}` handler routes it to the interpreter's
  # restricted entry.
  #
  # This is also why the proc cannot recurse: the bolt it casts is magic, and
  # only the weapon-attack path above ever reaches `dispatch_dealt_damage/4`.
  defp drain_auto_cast({:auto_cast, skill_name, level, target}) do
    case Catalog.by_name(skill_name) do
      {:ok, definition} ->
        GenServer.cast(self(), {:skill, {:auto_cast, definition.id, level, target}})

      :error ->
        raise "auto-cast of unknown skill #{inspect(skill_name)} at level #{level}: " <>
                "a status named a skill absent from the catalog"
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
          from_caster?: true,
          basic_attack?: true
        }

        prepared_hits =
          Enum.map(1..hits//1, fn _ ->
            DamageApplication.prepare_unit_damage(
              :mob,
              target_id,
              damage,
              hit_info,
              attacker_combatant.unit_id
            )
          end)

        Enum.each(prepared_hits, fn {final_damage, prepared_hit_info} ->
          DamageApplication.apply_unit_damage(
            :mob,
            target_pid,
            target_id,
            final_damage,
            prepared_hit_info,
            attacker_combatant.unit_id
          )
        end)

        broadcast_basic_attack(attacker_combatant, target_combatant, damage_result, prepared_hits)

      :player ->
        hit_info = %{
          dmg_type: :physical,
          is_short: true,
          element: attacker_combatant.weapon.element,
          skill_id: nil,
          skill_level: nil,
          from_caster?: true,
          basic_attack?: true
        }

        {final_damage, prepared_hit_info} =
          DamageApplication.prepare_unit_damage(
            :player,
            target_id,
            damage,
            hit_info,
            {:player, attacker_combatant.unit_id}
          )

        DamageApplication.broadcast_nearby(
          target_combatant,
          PacketFactory.build_attack_packet(
            attacker_combatant,
            target_combatant,
            %{damage_result | damage: final_damage}
          )
        )

        DamageApplication.apply_unit_damage(
          :player,
          target_pid,
          target_id,
          final_damage,
          prepared_hit_info,
          {:player, attacker_combatant.unit_id}
        )

      :homunculus ->
        hit_info = %{
          dmg_type: :physical,
          is_short: true,
          element: attacker_combatant.weapon.element,
          skill_id: nil,
          skill_level: nil,
          from_caster?: true,
          basic_attack?: true
        }

        {final_damage, prepared_hit_info} =
          DamageApplication.prepare_unit_damage(
            :homunculus,
            target_id,
            damage,
            hit_info,
            {:player, attacker_combatant.unit_id}
          )

        DamageApplication.broadcast_nearby(
          target_combatant,
          PacketFactory.build_attack_packet(
            attacker_combatant,
            target_combatant,
            %{damage_result | damage: final_damage}
          )
        )

        DamageApplication.apply_unit_damage(
          :homunculus,
          target_pid,
          target_id,
          final_damage,
          prepared_hit_info,
          {:player, attacker_combatant.unit_id}
        )

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

  defp broadcast_basic_attack(attacker, target, damage_result, prepared_hits) do
    damages = Enum.map(prepared_hits, &elem(&1, 0))

    if length(damages) > 1 and length(Enum.uniq(damages)) > 1 do
      Enum.each(damages, fn damage ->
        DamageApplication.broadcast_nearby(
          target,
          PacketFactory.build_attack_packet(attacker, target, %{damage_result | damage: damage})
        )
      end)
    else
      DamageApplication.broadcast_nearby(
        target,
        PacketFactory.build_attack_packet(
          attacker,
          target,
          %{damage_result | damage: hd(damages)},
          length(damages)
        )
      )
    end

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
           DamageApplication.damage_skill_unit(
             manager_pid,
             target_id,
             damage,
             {:player, attacker_id}
           ) do
      broadcast_skill_unit_attack(attacker, target, damage_result)
    end
  end

  defp broadcast_skill_unit_attack(attacker, target, damage_result) do
    packet = PacketFactory.build_attack_packet(attacker, target, damage_result)
    DamageApplication.broadcast_nearby(target, packet)
  end

  defp handle_mob_attack_hit(
         damage_result,
         attacker_combatant,
         target_combatant,
         target_pid,
         target_type,
         target_id
       ) do
    damage = damage_result.damage
    is_critical = damage_result.is_critical

    Logger.debug(
      "Combat: Mob #{attacker_combatant.unit_id} attacking player #{target_id} for #{damage} damage#{if is_critical, do: " (CRITICAL)", else: ""}"
    )

    # Show the hit animation/damage number first, then apply HP loss so the
    # SP_HP update (and any death) follows the visible strike.
    # NOTE: no equipment-break roll on the mob path — mob attackers carry no break
    # bonuses and natural break is player-only; this is the future hook for
    # mob-skill-driven breaks (rAthena `skill_break_equip`) once those exist.
    hit_info = %{
      dmg_type: :physical,
      is_short: attacker_combatant.attack_range <= 3,
      element: attacker_combatant.weapon.element,
      skill_id: nil,
      skill_level: nil,
      from_caster?: true,
      basic_attack?: true
    }

    {damage, hit_info} =
      DamageApplication.prepare_unit_damage(
        target_type,
        target_id,
        damage,
        hit_info,
        mob_damage_source(target_type, attacker_combatant.unit_id)
      )

    attack_packet =
      PacketFactory.build_attack_packet(
        attacker_combatant,
        target_combatant,
        %{damage_result | damage: damage}
      )

    DamageApplication.broadcast_nearby(target_combatant, attack_packet)

    DamageApplication.apply_unit_damage(
      target_type,
      target_pid,
      target_id,
      damage,
      hit_info,
      mob_damage_source(target_type, attacker_combatant.unit_id)
    )

    OnHitEffects.after_hit(attacker_combatant, target_combatant, damage_result,
      attack_flag: normal_attack_flag(attacker_combatant)
    )

    dispatch_equip_autocasts(
      attacker_combatant,
      target_combatant,
      target_pid,
      normal_attack_flag(attacker_combatant)
    )
  end

  defp resolve_homunculus_attack({:miss}, attacker, target, _target_pid, _target_type, _target_hp) do
    DamageApplication.broadcast_nearby(target, PacketFactory.build_miss_packet(attacker, target))
    :ok
  end

  defp resolve_homunculus_attack(
         {:perfect_dodge},
         attacker,
         target,
         _target_pid,
         _target_type,
         _target_hp
       ) do
    DamageApplication.broadcast_nearby(
      target,
      PacketFactory.build_perfect_dodge_packet(attacker, target)
    )

    :ok
  end

  defp resolve_homunculus_attack(
         {:hit, damage_result},
         attacker,
         target,
         target_pid,
         target_type,
         target_hp
       ) do
    hit_info = %{
      dmg_type: :physical,
      is_short: attacker.attack_range <= 3,
      element: attacker.weapon.element,
      skill_id: nil,
      skill_level: nil,
      from_caster?: true,
      basic_attack?: true
    }

    source = {:homunculus, attacker.unit_id}

    {damage, hit_info} =
      DamageApplication.prepare_unit_damage(
        target_type,
        target.unit_id,
        damage_result.damage,
        hit_info,
        source
      )

    damage = min(damage, target_hp)

    packet =
      PacketFactory.build_attack_packet(attacker, target, %{damage_result | damage: damage})

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

    proc_effects =
      :homunculus
      |> StatusInterpreter.on_dealt_damage(attacker.unit_id, %{
        target: {target_type, target.unit_id},
        damage: damage,
        element: attacker.weapon.element,
        primary_basic_weapon_hit?: true
      })
      |> Enum.map(&homunculus_proc_effect/1)

    append_local_effects(delivery, proc_effects)
  end

  defp homunculus_proc_effect({:local_heal, target, amount, source}) do
    DamageApplication.local_heal_effect(target, amount, source)
  end

  defp homunculus_proc_effect(follow_up) do
    raise ArgumentError, "unsupported Homunculus dealt-damage follow-up: #{inspect(follow_up)}"
  end

  defp append_local_effects(delivery, []), do: delivery
  defp append_local_effects(:ok, effects), do: {:local_effects, effects}

  defp append_local_effects({:local_effects, current}, effects),
    do: {:local_effects, current ++ effects}

  defp typed_mob_target(target_id) when is_integer(target_id), do: {:player, target_id}
  defp typed_mob_target(target_ref), do: target_ref

  defp ensure_mob_targetable(target_state, :homunculus),
    do: TargetResolver.ensure_targetable(target_state, :homunculus)

  defp ensure_mob_targetable(_target_state, :player), do: :ok

  defp apply_vanish_override(swing, :none), do: swing

  defp apply_vanish_override(%HandedAttack{} = swing, {_resource, amount}) do
    %{
      swing
      | primary: %{swing.primary | damage: amount},
        secondary: nil,
        raw_total: amount
    }
  end

  defp settled_damage(%HandedAttack{primary: primary, secondary: nil}), do: primary.damage

  defp settled_damage(%HandedAttack{primary: primary, secondary: secondary}),
    do: primary.damage + secondary.damage

  defp player_damage_source(_target_type, attacker_id), do: {:player, attacker_id}

  defp mob_damage_source(_target_type, attacker_id), do: {:mob, attacker_id}

  defp validate_player_target(attacker, target, :homunculus),
    do: Targeting.validate_enemy(attacker, target)

  defp validate_player_target(attacker, target, :player),
    do: Targeting.validate_enemy(attacker, target)

  defp validate_player_target(_attacker, _target, _target_type), do: :ok

  defp validate_homunculus_target(_attacker, _target, :skill_unit), do: :ok

  defp validate_homunculus_target(attacker, target, _type),
    do: Targeting.validate_enemy(attacker, target)

  defp check_hit_and_calculate_damage(attacker_combatant, defender_combatant) do
    attacker_stats = %{
      hit: attacker_combatant.combat_stats.hit,
      char_id: attacker_combatant.unit_id,
      perfect_hit: EquipmentBonuses.perfect_hit_rate(attacker_combatant),
      hit_rate_bonus_pct: Map.get(attacker_combatant.combat_stats, :hit_rate_bonus_pct, 0)
    }

    defender_stats = %{
      flee: defender_combatant.combat_stats.flee,
      perfect_dodge: defender_combatant.combat_stats.perfect_dodge,
      unit_id: defender_combatant.unit_id
    }

    case HitCalculations.calculate_hit_result(attacker_stats, defender_stats) do
      :hit ->
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
end
