defmodule Aesir.ZoneServer.Unit.CombatCalculations do
  @moduledoc """
  Behavior defining combat calculation interface for all unit types.

  This behavior ensures consistent combat stat calculations while allowing
  for unit-specific implementations. Each unit type (Player, Mob, etc.) can
  implement their own calculation logic while maintaining a common interface.

  ## Implementation Notes

  - Player calculations are complex, involving equipment, status effects, and job bonuses
  - Mob combat stats come from `Mechanics.mob_formulas/0` through `Unit.Mob.Stats`

  ## Required Callbacks

  All callbacks receive the unit's stats and return calculated stat values.
  """

  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @typedoc "The stats a unit's combat values derive from."
  @type unit_data :: PlayerStats.t()

  @doc """
  Calculates the hit stat for accuracy calculations.

  Compared with target FLEE through the active mode's hit-rate formula.

  ## Parameters
    - unit_data: Unit-specific data containing base stats and modifiers
    
  ## Returns
    - Integer representing the calculated hit value
  """
  @callback calculate_hit(unit_data()) :: integer()

  @doc """
  Calculates the flee stat for evasion calculations.

  Compared with attacker HIT through the active mode's hit-rate formula.

  ## Parameters
    - unit_data: Unit-specific data containing base stats and modifiers
    
  ## Returns
    - Integer representing the calculated flee value
  """
  @callback calculate_flee(unit_data()) :: integer()

  @doc """
  Calculates perfect dodge stat for perfect dodge mechanics.

  Used in perfect dodge check: rand(1000) < perfect_dodge

  ## Parameters
    - unit_data: Unit-specific data containing base stats and modifiers
    
  ## Returns
    - Integer representing the calculated perfect dodge value
  """
  @callback calculate_perfect_dodge(unit_data()) :: integer()

  @doc """
  Calculates attack speed stat for combat timing.

  Used for attack animation timing and combat flow.

  ## Parameters
    - unit_data: Unit-specific data containing base stats and modifiers
    
  ## Returns
    - Integer representing the calculated ASPD value
  """
  @callback calculate_aspd(unit_data()) :: integer()

  @doc """
  Calculates base attack stat for damage calculations.

  Used in damage formulas before applying modifiers.

  ## Parameters
    - unit_data: Unit-specific data containing base stats and modifiers
    
  ## Returns
    - Integer representing the calculated base attack value
  """
  @callback calculate_base_attack(unit_data()) :: integer()

  @doc """
  Calculates defense stat for damage reduction.

  Used in damage calculations for reducing incoming damage.

  ## Parameters
    - unit_data: Unit-specific data containing base stats and modifiers
    
  ## Returns
    - Integer representing the calculated defense value
  """
  @callback calculate_defense(unit_data()) :: integer()
end
