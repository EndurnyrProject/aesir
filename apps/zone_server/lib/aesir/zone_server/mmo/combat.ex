defmodule Aesir.ZoneServer.Mmo.Combat do
  @moduledoc """
  Core combat system orchestrating damage calculations and application.
  """

  require Logger

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Combat packets broadcast from the victim's position, per rAthena.
  @combat_view_range 14

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
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_attack_with_combatants(attacker_combatant, target_combatant),
         {:ok, combat_result} <-
           check_hit_and_calculate_damage_with_combatants(attacker_combatant, target_combatant) do
      case combat_result do
        {:miss} ->
          Logger.debug(
            "Combat: Player #{attacker_combatant.unit_id} attack missed #{target_type} #{target_id}"
          )

          # Broadcast miss packet to nearby players
          miss_packet = PacketFactory.build_miss_packet(attacker_combatant, target_combatant)
          broadcast_to_nearby_players(target_combatant, miss_packet)

        {:perfect_dodge} ->
          Logger.debug(
            "Combat: Player #{attacker_combatant.unit_id} attack perfect dodged by #{target_type} #{target_id}"
          )

          # Broadcast perfect dodge packet to nearby players
          dodge_packet =
            PacketFactory.build_perfect_dodge_packet(attacker_combatant, target_combatant)

          broadcast_to_nearby_players(target_combatant, dodge_packet)

        {:hit, damage_result} ->
          handle_player_attack_hit(
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
  end

  defp handle_player_attack_hit(
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
      "Combat: Player #{attacker_combatant.unit_id} attacking #{target_type} #{target_id} for #{damage} damage#{if is_critical, do: " (CRITICAL)", else: ""}"
    )

    case target_type do
      :mob ->
        MobSession.apply_damage(target_pid, damage, attacker_combatant.unit_id)
        :ok

      :player ->
        Logger.warning("PvP combat not yet implemented")
        {:error, :pvp_not_implemented}
    end

    attack_packet =
      PacketFactory.build_attack_packet(attacker_combatant, target_combatant, damage_result)

    broadcast_to_nearby_players(target_combatant, attack_packet)
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

      case target_type do
        :mob ->
          MobSession.apply_damage(target_pid, damage)
          :ok

        :player ->
          PlayerSession.apply_damage(target_pid, damage)
          :ok
      end
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

    PlayerSession.apply_damage(target_pid, damage, attacker_combatant.unit_id)
  end

  # New function that returns actual unit states instead of maps
  defp get_target_unit_state(target_id) do
    case get_mob_unit_state(target_id) do
      {:ok, pid, mob_state, :mob} -> {:ok, pid, mob_state, :mob}
      {:error, :not_found} -> get_player_unit_state(target_id)
      {:error, :target_no_pid} -> {:error, :target_no_pid}
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

  # New combatant-based functions
  defp validate_attack_with_combatants(attacker_combatant, target_combatant) do
    # Validate attack range using combatant positions for players
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
    Broadcast.to_in_range(target.map_name, x, y, @combat_view_range, packet)
  end
end
