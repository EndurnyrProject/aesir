defmodule Aesir.ZoneServer.Mmo.Combat.DamageCalculator do
  @moduledoc """
  Unified damage calculation system for all unit types.

  This module consolidates the duplicate damage calculation logic that was
  previously split between player and mob combat systems. It provides a
  single, authoritative implementation of the Renewal damage formula.

  ## Key Features

  - Unified damage calculation for all unit types (players, mobs, future units)
  - Composable modifier pipeline (size, race, element, status effects)
  - Renewal defense formula implementation
  - Critical hit processing

  ## Usage

      attacker_combatant = %{...}  # Standardized combatant structure
      defender_combatant = %{...}  # Standardized combatant structure
      
      case DamageCalculator.calculate_damage(attacker_combatant, defender_combatant) do
        {:ok, damage_result} -> 
          # damage_result contains: %{damage: integer(), is_critical: boolean()}
        {:error, reason} ->
          # Handle error
      end
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers

  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @typedoc """
  Result of damage calculation containing final damage and critical hit status.
  """
  @type damage_result :: %{
          damage: non_neg_integer(),
          is_critical: boolean()
        }

  @typedoc """
  Standardized combatant structure for damage calculations.
  References the Combatant struct defined in the Combatant module.
  """
  @type combatant :: Combatant.t()

  @doc """
  Calculates damage from attacker to defender using unified Renewal formula.

  This is the main entry point for all damage calculations, regardless of
  unit type (player, mob, future units). The function handles:

  1. Base attack calculation (delegated to unit-specific logic)
  2. Modifier applications (size, race, element, status effects)
  3. Defense calculations (Renewal formula)
  4. Critical hit processing

  ## Parameters
    - attacker: Standardized combatant structure for attacker
    - defender: Standardized combatant structure for defender

  ## Returns
    - {:ok, damage_result} on success
    - {:error, reason} on failure

  ## Examples

      attacker = build_player_combatant(player_stats)
      defender = build_mob_combatant(mob_data)
      
      case DamageCalculator.calculate_damage(attacker, defender) do
        {:ok, %{damage: 150, is_critical: false}} ->
          apply_damage_to_target(defender, 150)
        {:error, reason} ->
          handle_damage_error(reason)
      end
  """
  @spec calculate_damage(combatant(), combatant()) :: {:ok, damage_result()} | {:error, atom()}
  def calculate_damage(attacker, defender) do
    with {:ok, base_atk} <- calculate_base_attack(attacker),
         {:ok, total_atk} <- apply_modifier_pipeline(base_atk, attacker, defender),
         {:ok, final_damage} <- apply_defense_formula(total_atk, defender),
         {:ok, critical_result} <- apply_critical_hit(final_damage, attacker) do
      {:ok, critical_result}
    else
      error -> error
    end
  end

  @doc """
  Calculates base attack value based on unit type and stats.

  This function delegates to unit-specific base attack calculation logic
  while providing a unified interface.
  """
  @spec calculate_base_attack(combatant()) :: {:ok, integer()} | {:error, atom()}
  def calculate_base_attack(%{unit_type: :player} = attacker) do
    # Player base attack formula: (STR * 2) + (DEX / 5) + (LUK / 3) + base_level/4
    stats = attacker.base_stats
    progression = attacker.progression

    base_atk =
      stats.str * 2 +
        div(stats.dex, 5) +
        div(stats.luk, 3) +
        div(progression.base_level, 4)

    weapon_atk = calculate_weapon_attack(attacker)
    mastery_bonus = calculate_mastery_bonus(attacker)

    total_base_atk = base_atk + weapon_atk + mastery_bonus

    {:ok, total_base_atk}
  end

  def calculate_base_attack(%{unit_type: :mob} = attacker) do
    # Mob base attack: use predefined attack value with variance
    base_atk = attacker.combat_stats.atk

    # Add variance (±25% like in original mob combat)
    # -25 to +25
    variance = :rand.uniform(51) - 26
    weapon_atk = round(base_atk * variance / 100)

    total_atk = base_atk + weapon_atk

    {:ok, total_atk}
  end

  def calculate_base_attack(_attacker) do
    {:error, :unknown_unit_type}
  end

  @doc """
  Applies the composable modifier pipeline to damage.

  Modifiers are applied in this order:
  1. Size modifiers
  2. Race modifiers  
  3. Element modifiers
  4. Status effect modifiers
  """
  @spec apply_modifier_pipeline(integer(), combatant(), combatant()) :: {:ok, integer()}
  def apply_modifier_pipeline(base_damage, attacker, defender) do
    total_atk =
      base_damage
      |> apply_size_modifier(attacker, defender)
      |> apply_race_modifier(attacker, defender)
      |> apply_element_modifier(attacker, defender)
      |> apply_status_effect_damage_modifiers(attacker)

    {:ok, total_atk}
  end

  @doc """
  Applies the Renewal defense reduction formula.

  Formula: Attack * (4000 + eDEF) / (4000 + eDEF*10) - sDEF

  Where:
  - eDEF = equipment/hard defense
  - sDEF = soft defense (VIT-based)
  """
  @spec apply_defense_formula(number(), combatant()) :: {:ok, integer()}
  def apply_defense_formula(total_atk, defender) do
    hard_def = defender.combat_stats.def
    soft_def = calculate_soft_defense(defender)

    # Apply status effect defense modifiers
    {modified_hard_def, modified_soft_def} =
      apply_status_effect_defense_modifiers(hard_def, soft_def, defender)

    # Apply Renewal defense reduction formula
    # Handle edge case where hard_def = -400 (causes division by zero)
    effective_hard_def = if modified_hard_def == -400, do: -399, else: modified_hard_def

    base_damage =
      total_atk * (4000 + effective_hard_def) / (4000 + 10 * effective_hard_def) -
        modified_soft_def

    final_damage = max(1, trunc(base_damage))

    Logger.debug(
      "Defense calculation: total_atk=#{trunc(total_atk)}, hard_def=#{modified_hard_def}, soft_def=#{modified_soft_def}, final_damage=#{final_damage}"
    )

    {:ok, final_damage}
  end

  @doc """
  Applies critical hit calculation to final damage.
  """
  @spec apply_critical_hit(integer(), combatant()) :: {:ok, damage_result()}
  def apply_critical_hit(base_damage, attacker) do
    attacker_for_crit = %{luk: attacker.base_stats.luk}
    critical_result = CriticalHits.calculate_critical_hit(attacker_for_crit, base_damage)

    Logger.debug(
      "Critical hit check: base_damage=#{base_damage}, final_damage=#{critical_result.damage}#{if critical_result.is_critical, do: " (CRITICAL)", else: ""}"
    )

    {:ok, critical_result}
  end

  # Private helper functions

  defp calculate_weapon_attack(%{unit_type: :player} = attacker) do
    # TODO: Get actual weapon attack from equipment
    # For now, use a base weapon attack based on level (same as original)
    base_weapon_attack = div(attacker.progression.base_level, 4) + 5

    # Add some variance (±5%)
    variance = :rand.uniform(11) - 6
    weapon_attack = base_weapon_attack + div(base_weapon_attack * variance, 100)

    max(1, weapon_attack)
  end

  defp calculate_weapon_attack(_attacker), do: 0

  defp calculate_mastery_bonus(_attacker) do
    # TODO: Implement weapon mastery based on skills
    0
  end

  defp calculate_soft_defense(%{unit_type: :player} = defender) do
    # Renewal: soft_def = vit (direct VIT value)
    defender.base_stats.vit
  end

  defp calculate_soft_defense(%{unit_type: :mob}) do
    # Mobs typically don't have separate soft defense calculation
    0
  end

  # Modifier application functions (unified from original Combat module)

  defp apply_element_modifier(damage, attacker, defender) do
    attack_element = Map.get(attacker.weapon, :element, :neutral)

    case Map.get(defender, :element, {:neutral, 1}) do
      {defender_element, defender_level} ->
        modifier = ElementModifiers.get_modifier(attack_element, defender_element, defender_level)
        damage * modifier

      _ ->
        damage
    end
  end

  defp apply_size_modifier(damage, attacker, defender) do
    attacker_size = Map.get(attacker.weapon, :size, SizeModifiers.player_size())
    defender_size = Map.get(defender, :size, SizeModifiers.player_size())

    modifier = SizeModifiers.get_modifier(attacker_size, defender_size)
    damage * modifier
  end

  defp apply_race_modifier(damage, _attacker, defender) do
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

  defp apply_status_effect_damage_modifiers(damage, attacker) do
    # Get unit type and ID for status effect lookup
    {unit_type, unit_id} = get_unit_type_and_id(attacker)

    # Get all status effect modifiers
    modifiers = ModifierCalculator.get_all_modifiers(unit_type, unit_id)

    # Apply damage-related modifiers
    damage_modifier = Map.get(modifiers, :damage_bonus, 0) + Map.get(modifiers, :atk_bonus, 0)
    damage_multiplier = 1.0 + Map.get(modifiers, :damage_multiplier, 0.0)

    Logger.debug(
      "Status effect damage modifiers: bonus=#{damage_modifier}, multiplier=#{damage_multiplier}"
    )

    (damage + damage_modifier) * damage_multiplier
  end

  defp apply_status_effect_defense_modifiers(hard_def, soft_def, defender) do
    {unit_type, unit_id} = get_unit_type_and_id(defender)

    # Get all status effect modifiers
    modifiers = ModifierCalculator.get_all_modifiers(unit_type, unit_id)

    # Apply defense-related modifiers
    hard_def_bonus = Map.get(modifiers, :def_bonus, 0)
    soft_def_bonus = Map.get(modifiers, :vit_bonus, 0)

    defense_multiplier = 1.0 + Map.get(modifiers, :defense_multiplier, 0.0)

    Logger.debug(
      "Status effect defense modifiers: hard_def_bonus=#{hard_def_bonus}, soft_def_bonus=#{soft_def_bonus}, multiplier=#{defense_multiplier}"
    )

    modified_hard_def = trunc((hard_def + hard_def_bonus) * defense_multiplier)
    modified_soft_def = trunc((soft_def + soft_def_bonus) * defense_multiplier)

    {modified_hard_def, modified_soft_def}
  end

  defp get_unit_type_and_id(combatant) do
    case combatant.unit_type do
      :player -> {:player, combatant.unit_id}
      :mob -> {:monster, combatant.unit_id}
      _ -> {:unknown, combatant.unit_id}
    end
  end
end
