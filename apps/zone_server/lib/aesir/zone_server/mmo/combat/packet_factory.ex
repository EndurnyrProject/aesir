defmodule Aesir.ZoneServer.Mmo.Combat.PacketFactory do
  @moduledoc """
  Factory module for creating combat-related network packets.

  This module consolidates all packet creation logic for combat operations,
  providing a clean interface for the main Combat module. It handles the
  creation of attack, miss, dodge, and other combat-related packets.

  ## Key Features

  - Unified packet creation interface
  - Support for both player and mob combat packets
  - Automatic server tick and timing calculations
  - Consistent logging for all packet types

  ## Usage

      # Create attack packet
      packet = PacketFactory.build_attack_packet(attacker_combatant, defender_combatant, damage_result)
      
      # Create miss packet
      packet = PacketFactory.build_miss_packet(attacker_combatant, defender_combatant)
      
      # All packets can be broadcast using the same interface
      broadcast_to_nearby_players(defender_combatant, packet)
  """

  require Logger

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Packets.ZcNotifyAct

  @typedoc """
  Result of damage calculation containing final damage and critical hit status.
  """
  @type damage_result :: %{
          damage: non_neg_integer(),
          is_critical: boolean()
        }

  @doc """
  Builds an attack packet for successful attacks.

  Creates the appropriate ZcNotifyAct packet for attack results,
  including damage values and critical hit status.

  ## Parameters
    - attacker: Combatant struct for the attacker
    - defender: Combatant struct for the defender
    - damage_result: Result from damage calculation

  ## Returns
    - ZcNotifyAct packet ready for broadcasting
  """
  @spec build_attack_packet(Combatant.t(), Combatant.t(), damage_result()) :: struct()
  def build_attack_packet(attacker, defender, damage_result) do
    attacker_id = attacker.gid
    defender_id = defender.gid
    aspd = get_aspd_from_combatant(attacker)

    Logger.debug(
      "Combat packet: #{if damage_result.is_critical, do: "CRITICAL ", else: ""}attack from #{attacker_id} to #{defender_id} for #{damage_result.damage} damage"
    )

    ZcNotifyAct.from_combat_result(
      attacker_id,
      defender_id,
      damage_result,
      server_tick: ServerTick.now(),
      src_speed: aspd * 10,
      dmg_speed: 500
    )
  end

  @doc """
  Builds a miss packet for failed attacks.

  Creates the appropriate ZcNotifyAct packet for missed attacks.

  ## Parameters
    - attacker: Combatant struct for the attacker
    - defender: Combatant struct for the defender

  ## Returns
    - ZcNotifyAct miss packet ready for broadcasting
  """
  @spec build_miss_packet(Combatant.t(), Combatant.t()) :: struct()
  def build_miss_packet(attacker, defender) do
    attacker_id = attacker.gid
    defender_id = defender.gid
    aspd = get_aspd_from_combatant(attacker)

    Logger.debug("Combat packet: Miss from #{attacker_id} to #{defender_id}")

    ZcNotifyAct.miss_attack(
      attacker_id,
      defender_id,
      server_tick: ServerTick.now(),
      src_speed: aspd * 10,
      dmg_speed: 0
    )
  end

  @doc """
  Builds a perfect dodge packet for perfectly dodged attacks.

  Creates the appropriate ZcNotifyAct packet for perfect dodge events.

  ## Parameters
    - attacker: Combatant struct for the attacker
    - defender: Combatant struct for the defender

  ## Returns
    - ZcNotifyAct dodge packet ready for broadcasting
  """
  @spec build_perfect_dodge_packet(Combatant.t(), Combatant.t()) :: struct()
  def build_perfect_dodge_packet(attacker, defender) do
    attacker_id = attacker.gid
    defender_id = defender.gid
    aspd = get_aspd_from_combatant(attacker)

    Logger.debug("Combat packet: Perfect dodge from #{attacker_id} to #{defender_id}")

    # Perfect dodge uses the same packet structure as miss
    ZcNotifyAct.miss_attack(
      attacker_id,
      defender_id,
      server_tick: ServerTick.now(),
      src_speed: aspd * 10,
      dmg_speed: 0
    )
  end

  @doc """
  Creates packets for any combat result type.

  This is a convenience function that dispatches to the appropriate
  packet creation function based on the combat result.

  ## Parameters
    - attacker: Combatant struct for the attacker
    - defender: Combatant struct for the defender
    - combat_result: Result from combat calculations

  ## Returns
    - Appropriate ZcNotifyAct packet for the combat result
  """
  @spec build_combat_packet(Combatant.t(), Combatant.t(), term()) :: struct()
  def build_combat_packet(attacker, defender, combat_result) do
    case combat_result do
      {:hit, damage_result} ->
        build_attack_packet(attacker, defender, damage_result)

      {:miss} ->
        build_miss_packet(attacker, defender)

      {:perfect_dodge} ->
        build_perfect_dodge_packet(attacker, defender)

      _ ->
        raise ArgumentError, "Unknown combat result type: #{inspect(combat_result)}"
    end
  end

  # Private helper functions

  # Extracts ASPD from combatant for packet timing calculations.
  #
  # Handles the different ways ASPD might be stored in combatant data
  # for backward compatibility during the transition period.
  @spec get_aspd_from_combatant(Combatant.t()) :: integer()
  defp get_aspd_from_combatant(%Combatant{} = combatant) do
    # For now, we'll need to calculate ASPD or get it from derived stats
    # This is a simplified version - in the full implementation,
    # we'd want to store ASPD in the combatant struct

    # Default ASPD calculation based on AGI (simplified)
    base_aspd = 200 - combatant.base_stats.agi
    max(100, base_aspd)
  end

  @doc """
  Legacy helper for backward compatibility.

  Extracts ASPD from old-style attacker data during transition period.
  """
  @spec get_aspd_from_legacy_attacker(map()) :: integer()
  def get_aspd_from_legacy_attacker(attacker_data) do
    cond do
      Map.has_key?(attacker_data, :derived_stats) ->
        attacker_data.derived_stats.aspd

      Map.has_key?(attacker_data, :aspd) ->
        attacker_data.aspd

      Map.has_key?(attacker_data, :base_stats) ->
        # Fallback calculation
        base_aspd = 200 - attacker_data.base_stats.agi
        max(100, base_aspd)

      true ->
        # Default ASPD
        150
    end
  end

end
