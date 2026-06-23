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

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat.Combatant

  # e_damage_type: single-hit skill display (rAthena DMG_SINGLE).
  @dmg_single 6

  # ZC_NOTIFY_ACT attack types (rAthena clif e_damage_type for basic attacks).
  @attack_type_normal 0
  @attack_type_multi_hit 4
  @attack_type_critical 8
  @attack_type_lucky_dodge 10

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
  @spec build_attack_packet(Combatant.t(), Combatant.t(), damage_result(), pos_integer()) ::
          struct()
  def build_attack_packet(attacker, defender, damage_result, hits \\ 1)

  def build_attack_packet(attacker, defender, damage_result, 1) do
    attacker_id = attacker.unit_id
    defender_id = defender.unit_id

    type = if damage_result.is_critical, do: @attack_type_critical, else: @attack_type_normal

    %DamageDealt{
      src_id: attacker_id,
      target_id: defender_id,
      server_tick: ServerTick.now(),
      src_speed: attacker.attack_delay_ms,
      dmg_speed: 500,
      damage: damage_result.damage,
      div: 1,
      type: type,
      damage2: 0,
      is_sp_damage: false
    }
  end

  # Multi-hit attack (e.g. Double Attack): `damage_result.damage` is the per-hit
  # value; the packet carries the combined total and `div = hits`, so the client
  # divides it back into the individual hit numbers (rAthena DAMAGE_DIV_FIX).
  def build_attack_packet(attacker, defender, damage_result, hits) when hits > 1 do
    attacker_id = attacker.unit_id
    defender_id = defender.unit_id
    total_damage = damage_result.damage * hits

    %DamageDealt{
      src_id: attacker_id,
      target_id: defender_id,
      server_tick: ServerTick.now(),
      src_speed: attacker.attack_delay_ms,
      dmg_speed: 500,
      damage: total_damage,
      div: hits,
      type: @attack_type_multi_hit,
      damage2: 0,
      is_sp_damage: false
    }
  end

  @doc """
  Builds a skill-damage packet (ZC_NOTIFY_SKILL) for an offensive skill hit.

  ## Parameters
    - attacker: Combatant struct for the caster
    - defender: Combatant struct for the target
    - skill_id: skill database id
    - skill_level: cast level
    - damage_result: result from skill damage calculation

  ## Returns
    - SkillDamage packet ready for broadcasting
  """
  @spec build_skill_damage_packet(
          Combatant.t(),
          Combatant.t(),
          integer(),
          integer(),
          damage_result()
        ) :: SkillDamage.t()
  def build_skill_damage_packet(attacker, defender, skill_id, skill_level, damage_result) do
    %SkillDamage{
      skill_id: skill_id,
      level: skill_level,
      src_id: attacker.unit_id,
      target_id: defender.unit_id,
      server_tick: ServerTick.now(),
      src_delay: attacker.attack_delay_ms,
      dst_delay: 500,
      damage: damage_result.damage,
      div: 1,
      type: @dmg_single
    }
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
    attacker_id = attacker.unit_id
    defender_id = defender.unit_id

    build_miss(attacker_id, defender_id, attacker.attack_delay_ms)
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
    attacker_id = attacker.unit_id
    defender_id = defender.unit_id

    # Perfect dodge uses the same packet structure as miss.
    build_miss(attacker_id, defender_id, attacker.attack_delay_ms)
  end

  @spec build_miss(integer(), integer(), integer()) :: DamageDealt.t()
  defp build_miss(src_id, target_id, delay_ms) do
    %DamageDealt{
      src_id: src_id,
      target_id: target_id,
      server_tick: ServerTick.now(),
      src_speed: delay_ms,
      dmg_speed: 0,
      damage: 0,
      div: 1,
      type: @attack_type_lucky_dodge,
      damage2: 0,
      is_sp_damage: false
    }
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
end
