defmodule Aesir.ZoneServer.Mmo.Combat do
  @moduledoc """
  Core combat system orchestrating damage calculations and application.

  Implements rAthena-style combat formulas with integration to existing
  Aesir systems (stats, status effects, entity management).

  This module provides the main entry point for all combat actions,
  handling validation, damage calculation, and result application.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Executes an attack from attacker to target.

  Flow:
  1. Validate attack (range, target exists, cooldowns)
  2. Get attacker/defender stats  
  3. Calculate damage using rAthena formulas
  4. Apply damage to target
  5. Broadcast combat packets
  6. Handle death/rewards if applicable

  ## Parameters
    - attacker_pid: PID of the attacking player
    - target_id: ID of the target entity

  ## Returns
    - :ok if attack was successful
    - {:error, reason} if attack failed
  """
  @spec execute_attack(pid(), integer()) :: :ok | {:error, atom()}
  def execute_attack(attacker_pid, target_id) do
    with {:ok, attacker_stats} <- get_attacker_stats(attacker_pid),
         {:ok, target_pid, target_stats, target_type} <- get_target_stats(target_id),
         :ok <- validate_attack(attacker_stats, target_stats),
         {:ok, damage} <- calculate_damage(attacker_stats, target_stats) do
      Logger.debug(
        "Combat: Player #{attacker_stats.char_id} attacking #{target_type} #{target_id} for #{damage} damage"
      )

      # Apply damage using EXISTING MobSession.apply_damage/3
      case target_type do
        :mob ->
          MobSession.apply_damage(target_pid, damage, attacker_stats.char_id)
          :ok

        :player ->
          # TODO: Implement PvP damage application in future
          Logger.warning("PvP combat not yet implemented")
          {:error, :pvp_not_implemented}
      end

      # TODO: Broadcast damage packet to nearby players
      # broadcast_damage_packet(attacker_stats, target_stats, damage)
    else
      error -> error
    end
  end

  @doc """
  Deals damage to a target entity (used by status effects).

  This is a simplified version of execute_attack that bypasses
  validation and is used by status effects and other systems.
  """
  @spec deal_damage(integer(), integer(), atom(), atom()) :: :ok | {:error, atom()}
  def deal_damage(target_id, damage, element \\ :neutral, source_type \\ :status_effect) do
    with {:ok, target_pid, _target_stats, target_type} <- get_target_stats(target_id) do
      Logger.debug(
        "Combat: Dealing #{damage} #{element} damage to #{target_type} #{target_id} from #{source_type}"
      )

      case target_type do
        :mob ->
          MobSession.apply_damage(target_pid, damage)
          :ok

        :player ->
          # TODO: Implement player damage application
          Logger.warning("Player damage application not yet implemented")
          {:error, :player_damage_not_implemented}
      end
    end
  end

  defp get_attacker_stats(attacker_pid) do
    stats = PlayerSession.get_current_stats(attacker_pid)
    player_state = PlayerSession.get_state(attacker_pid)
    attacker_info = build_attacker_info(stats, player_state)
    {:ok, attacker_info}
  end

  defp build_attacker_info(stats, player_state) do
    %{
      char_id: player_state.character.id,
      base_stats: stats.base_stats,
      combat_stats: stats.combat_stats,
      derived_stats: stats.derived_stats,
      progression: stats.progression,
      position: {player_state.game_state.position.x, player_state.game_state.position.y},
      # TODO: Add equipment info for weapon size/element
      weapon: %{element: :neutral, size: SizeModifiers.weapon_size(:sword)}
    }
  end

  defp get_target_stats(target_id) do
    case get_mob_target_stats(target_id) do
      {:ok, pid, target_stats, :mob} -> {:ok, pid, target_stats, :mob}
      {:error, :not_found} -> get_player_target_stats(target_id)
      {:error, :target_no_pid} -> {:error, :target_no_pid}
    end
  end

  defp get_mob_target_stats(target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, mob_state, pid}} when is_pid(pid) ->
        target_stats = build_mob_target_stats(target_id, mob_state)
        {:ok, pid, target_stats, :mob}

      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, {_module, _state, nil}} ->
        {:error, :target_no_pid}
    end
  end

  defp get_player_target_stats(target_id) do
    case UnitRegistry.get_player_pid(target_id) do
      {:ok, pid} ->
        stats = PlayerSession.get_current_stats(pid)
        player_state = PlayerSession.get_state(pid)
        target_stats = build_player_target_stats(target_id, stats, player_state)
        {:ok, pid, target_stats, :player}

      {:error, :not_found} ->
        Logger.warning("Target #{target_id} not found in registry")
        {:error, :target_not_found}
    end
  end

  defp build_mob_target_stats(target_id, mob_state) do
    %{
      unit_id: target_id,
      base_stats: mob_state.base_stats,
      combat_stats: mob_state.combat_stats,
      derived_stats: mob_state.derived_stats,
      element: mob_state.element,
      race: mob_state.race,
      size: mob_state.size,
      position: {mob_state.position.x, mob_state.position.y}
    }
  end

  defp build_player_target_stats(target_id, stats, player_state) do
    %{
      unit_id: target_id,
      base_stats: stats.base_stats,
      combat_stats: stats.combat_stats,
      derived_stats: stats.derived_stats,
      race: RaceModifiers.player_race(),
      size: SizeModifiers.player_size(),
      position: {player_state.game_state.position.x, player_state.game_state.position.y}
    }
  end

  defp validate_attack(attacker_stats, target_stats) do
    # Basic range check - RO attack range is typically 1-2 cells
    attack_range = 2
    {attacker_x, attacker_y} = attacker_stats.position
    {target_x, target_y} = target_stats.position

    distance = calculate_distance(attacker_x, attacker_y, target_x, target_y)

    if distance <= attack_range do
      # TODO: Add more validation:
      # - Attack cooldown check
      # - Player is not sitting/stunned
      # - Target is not invincible
      # - Same map validation
      :ok
    else
      Logger.debug(
        "Attack failed: target out of range (distance: #{distance}, max: #{attack_range})"
      )

      {:error, :target_out_of_range}
    end
  end

  defp calculate_distance(x1, y1, x2, y2) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end

  defp calculate_damage(attacker, defender) do
    # Implement rAthena damage calculation pipeline
    base_atk = calculate_base_attack(attacker)
    weapon_atk = calculate_weapon_attack(attacker)
    mastery_bonus = calculate_mastery_bonus(attacker)

    total_atk = base_atk + weapon_atk + mastery_bonus

    Logger.debug(
      "Combat calculation: base_atk=#{base_atk}, weapon_atk=#{weapon_atk}, mastery=#{mastery_bonus}, total=#{total_atk}"
    )

    # Apply modifiers using the dedicated modules
    total_atk = apply_size_modifier(total_atk, attacker, defender)
    total_atk = apply_race_modifier(total_atk, attacker, defender)
    total_atk = apply_element_modifier(total_atk, attacker, defender)

    # Defense calculation
    hard_def = defender.combat_stats.def
    soft_def = calculate_soft_defense(defender)

    final_damage = max(1, total_atk - hard_def - soft_def)

    Logger.debug(
      "Combat final: total_atk=#{trunc(total_atk)}, hard_def=#{hard_def}, soft_def=#{soft_def}, damage=#{trunc(final_damage)}"
    )

    {:ok, trunc(final_damage)}
  end

  # base_atk = (str * 2) + (dex / 5) + (luk / 3) + base_level / 4
  defp calculate_base_attack(attacker) do
    stats = attacker.base_stats
    progression = attacker.progression
    stats.str * 2 + div(stats.dex, 5) + div(stats.luk, 3) + div(progression.base_level, 4)
  end

  defp calculate_weapon_attack(attacker) do
    # TODO: Get actual weapon attack from equipment
    # For now, use a base weapon attack based on level
    base_weapon_attack = div(attacker.progression.base_level, 4) + 5

    # Add some variance (±5%)
    # -5 to +5
    variance = :rand.uniform(11) - 6
    weapon_attack = base_weapon_attack + div(base_weapon_attack * variance, 100)

    max(1, weapon_attack)
  end

  defp calculate_mastery_bonus(_attacker) do
    # TODO: Implement weapon mastery based on skills
    # For now, return 0
    0
  end

  # soft_def = vit + (vit / 2)
  defp calculate_soft_defense(defender) do
    vit = defender.base_stats.vit
    vit + div(vit, 2)
  end

  # Modifier applications using dedicated modules

  defp apply_element_modifier(damage, attacker, defender) do
    attack_element = Map.get(attacker.weapon, :element, :neutral)

    case Map.get(defender, :element, {:neutral, 1}) do
      {defender_element, defender_level} ->
        modifier = ElementModifiers.get_modifier(attack_element, defender_element, defender_level)
        damage * modifier

      _ ->
        # No element info available, no modifier
        damage
    end
  end

  defp apply_size_modifier(damage, attacker, defender) do
    attacker_size = Map.get(attacker.weapon, :size, SizeModifiers.player_size())
    defender_size = Map.get(defender, :size, SizeModifiers.player_size())

    modifier = SizeModifiers.get_modifier(attacker_size, defender_size)
    damage * modifier
  end

  defp apply_race_modifier(damage, attacker, defender) do
    defender_race = Map.get(defender, :race, RaceModifiers.player_race())

    # TODO: Pass actual attacker equipment/skills data
    attacker_data = %{
      weapon_cards: [],
      equipment: %{},
      skills: %{}
    }

    modifier = RaceModifiers.get_modifier(attacker_data, defender_race)
    damage * modifier
  end
end
