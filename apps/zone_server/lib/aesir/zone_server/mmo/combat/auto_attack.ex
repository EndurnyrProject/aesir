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

  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.HpDrain
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

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

    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target_state, target_type),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <-
           AttackValidator.validate(attacker_combatant, target_combatant, projectile?: true),
         {:ok, combat_result} <-
           check_hit_and_calculate_damage(attacker_combatant, target_combatant) do
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
    attacker_combatant = mob_state.__struct__.to_combatant(mob_state)

    with {:ok, target_pid, target_state, :player} <- TargetResolver.resolve(target_id),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <- AttackValidator.validate_mob_attack(attacker_combatant, target_combatant),
         {:ok, combat_result} <-
           check_hit_and_calculate_damage(attacker_combatant, target_combatant) do
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
            target_id
          )
      end

      :ok
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
    hits = attack_hits(player_state)

    with :ok <-
           handle_player_attack_hit(
             damage_result,
             attacker,
             target,
             target_pid,
             target_type,
             target_id,
             hits
           ) do
      roll_equipment_breaks(player_state, target_state, target_type, target_pid)
      dispatch_dealt_damage(attacker, target_type, target_id, damage_result)
      OnHitEffects.after_hit(attacker, target, damage_result)
      drain_hp(attacker, dealt_damage(damage_result.damage, target_type, hits))
      splash_attack(attacker, target)
      :ok
    end
  end

  # Recovers HP from the damage a landed swing dealt, when the attacker's
  # equipment carries the drain bonus. Rolled once per swing over the swing's
  # total damage (multi-hit included), never per delivered hit, so a multi-hit
  # proc does not multiply the number of rolls.
  #
  # The heal is a broadcast to the attacker's own session rather than a direct
  # state write: `execute_attack/3` runs inside that session, so it lands as an
  # ordinary message the single writer applies after the current one.
  # Only the mob path delivers the multi-hit; a skill unit takes a single hit
  # whatever the proc rolled, so the drain always reads the damage that actually
  # landed.
  defp dealt_damage(damage, :mob, hits), do: damage * hits
  defp dealt_damage(damage, _target_type, _hits), do: damage

  defp drain_hp(attacker, damage) do
    case HpDrain.roll(attacker, damage) do
      0 -> :ok
      heal -> DamageApplication.apply_heal(attacker.unit_id, heal, attacker.unit_id)
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

  defp splash_hit(attacker, {_unit_type, target_id}) do
    with {:ok, target_pid, target_state, target_type} <- TargetResolver.resolve(target_id),
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
  defp roll_equipment_breaks(player_state, target_state, target_type, target_pid) do
    target_type
    |> break_target(target_state)
    |> maybe_roll(player_state, target_pid)
  end

  # The `:player` clauses below are intentionally unreachable until PvP lands
  # (see the NOTE), so their dead-clause warnings are suppressed.
  @dialyzer {:no_match, break_target: 2, maybe_roll: 3}

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
    do: PlayerSession.break_equip(self(), break_slot(slot))

  defp dispatch_break({:target, slot}, target_pid),
    do: PlayerSession.break_equip(target_pid, break_slot(slot))

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

        prepared_hits =
          Enum.map(1..hits//1, fn _ ->
            DamageApplication.prepare_unit_damage(:mob, target_id, damage, hit_info)
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
      from_caster?: true
    }

    {damage, hit_info} =
      DamageApplication.prepare_unit_damage(:player, target_id, damage, hit_info)

    attack_packet =
      PacketFactory.build_attack_packet(
        attacker_combatant,
        target_combatant,
        %{damage_result | damage: damage}
      )

    DamageApplication.broadcast_nearby(target_combatant, attack_packet)

    DamageApplication.apply_unit_damage(
      :player,
      target_pid,
      target_id,
      damage,
      hit_info,
      attacker_combatant.unit_id
    )

    OnHitEffects.after_hit(attacker_combatant, target_combatant, damage_result)
  end

  defp check_hit_and_calculate_damage(attacker_combatant, defender_combatant) do
    attacker_stats = %{
      hit: attacker_combatant.combat_stats.hit,
      char_id: attacker_combatant.unit_id,
      perfect_hit: EquipmentBonuses.perfect_hit_rate(attacker_combatant)
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
