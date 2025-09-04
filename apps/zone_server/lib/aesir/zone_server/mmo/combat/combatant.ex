defmodule Aesir.ZoneServer.Mmo.Combat.Combatant do
  @moduledoc """
  Standardized combatant structure for combat operations.

  This module defines the unified data structure used by all combat systems,
  replacing the ad-hoc maps previously used for player and mob combat.
  It provides type safety and a clear contract for combat operations.

  ## Benefits

  - Type safety through struct definition
  - Clear documentation of required fields
  - Consistent interface for all unit types
  - Easier testing and debugging
  - Better IDE support

  ## Usage

      # Create combatant from player state
      player_combatant = Combat.Unit.to_combatant(player_state)
      
      # Create combatant from mob state  
      mob_combatant = Combat.Unit.to_combatant(mob_state)
      
      # Both can be used interchangeably in combat functions
      DamageCalculator.calculate_damage(player_combatant, mob_combatant)
  """

  use TypedStruct

  @typedoc """
  Standardized combatant structure containing all data needed for combat calculations.

  Fields are organized into logical groups:
  - Identity: unit_id, unit_type
  - Stats: base_stats, combat_stats, progression
  - Combat modifiers: element, race, size, weapon
  - Positioning: position, map_name
  """
  typedstruct do
    # Unit identification
    field :unit_id, integer(), enforce: true
    field :unit_type, :player | :mob, enforce: true
    field :gid, integer(), enforce: true

    # Base stats (STR, AGI, VIT, INT, DEX, LUK)
    field :base_stats,
          %{
            str: integer(),
            agi: integer(),
            vit: integer(),
            int: integer(),
            dex: integer(),
            luk: integer()
          },
          enforce: true

    # Combat-derived stats
    field :combat_stats,
          %{
            atk: integer(),
            def: integer(),
            hit: integer(),
            flee: integer(),
            perfect_dodge: integer()
          },
          enforce: true

    # Character progression
    field :progression,
          %{
            base_level: integer(),
            job_level: integer()
          },
          enforce: true

    # Element data (for damage calculation)
    field :element, tuple() | atom(), enforce: true

    # Race data (for modifier calculation)
    field :race, atom(), enforce: true

    # Size data (for modifier calculation)
    field :size, atom(), enforce: true

    # Weapon information
    field :weapon,
          %{
            type: atom(),
            element: atom(),
            size: atom()
          },
          enforce: true

    # Attack range for combat distance calculations
    field :attack_range, integer(), enforce: true

    # Position data (optional for some combat operations)
    field :position, {integer(), integer()}, enforce: false

    # Map context (optional)
    field :map_name, String.t(), enforce: false
  end

  @doc """
  Creates a new combatant struct with validation.

  Validates that all required fields are present and have correct types.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    combatant = struct(__MODULE__, attrs)
    {:ok, combatant}
  rescue
    e in ArgumentError ->
      {:error, "Invalid combatant data: #{Exception.message(e)}"}
  end

  @doc """
  Creates a new combatant struct, raising on invalid data.
  """
  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, combatant} -> combatant
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Validates that a combatant struct has all required fields for combat.
  """
  @spec validate_for_combat(t()) :: :ok | {:error, String.t()}
  def validate_for_combat(%__MODULE__{} = combatant) do
    cond do
      combatant.unit_id <= 0 ->
        {:error, "Invalid unit_id: must be positive integer"}

      combatant.unit_type not in [:player, :mob] ->
        {:error, "Invalid unit_type: must be :player or :mob"}

      not is_map(combatant.base_stats) ->
        {:error, "Invalid base_stats: must be map"}

      not is_map(combatant.combat_stats) ->
        {:error, "Invalid combat_stats: must be map"}

      combatant.progression.base_level <= 0 ->
        {:error, "Invalid base_level: must be positive integer"}

      true ->
        :ok
    end
  end

  @doc """
  Gets the unit identifier for this combatant.

  This is a convenience function that provides a unified way to get
  the unit ID regardless of the combatant's internal structure.
  """
  @spec get_unit_id(t()) :: integer()
  def get_unit_id(%__MODULE__{unit_id: unit_id}), do: unit_id

  @doc """
  Gets the unit type for this combatant.
  """
  @spec get_unit_type(t()) :: :player | :mob
  def get_unit_type(%__MODULE__{unit_type: unit_type}), do: unit_type

  @doc """
  Checks if this combatant is a player.
  """
  @spec player?(t()) :: boolean()
  def player?(%__MODULE__{unit_type: :player}), do: true
  def player?(_), do: false

  @doc """
  Checks if this combatant is a mob.
  """
  @spec mob?(t()) :: boolean()
  def mob?(%__MODULE__{unit_type: :mob}), do: true
  def mob?(_), do: false
end
