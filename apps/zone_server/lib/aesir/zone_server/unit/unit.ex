defmodule Aesir.ZoneServer.Unit do
  @moduledoc """
  Behaviour for game units (players, monsters, NPCs) that defines
  common properties and functions for status effects, combat, and other game mechanics.

  This behaviour ensures all units provide the necessary information
  for status effect calculations, combat operations, and other game mechanics.
  """

  @type entity_race ::
          :human
          | :undead
          | :beast
          | :demon
          | :dragon
          | :angel
          | :formless
          | :insect
          | :fish
          | :plant
  @type entity_element ::
          :neutral
          | :water
          | :earth
          | :fire
          | :wind
          | :poison
          | :holy
          | :shadow
          | :ghost
          | :undead
  @type entity_size :: :small | :medium | :large
  @type unit_type :: :player | :mob | :npc | :pet | :homunculus | :mercenary

  @doc """
  Returns the entity's race type.
  Used for immunity and resistance calculations.
  """
  @callback get_race(state :: any()) :: entity_race()

  @doc """
  Returns the entity's element type and level.
  Used for elemental resistance and immunity calculations.
  """
  @callback get_element(state :: any()) :: {entity_element(), integer()}

  @doc """
  Returns whether this entity is a boss monster.
  Boss monsters have special immunity rules.
  """
  @callback is_boss?(state :: any()) :: boolean()

  @doc """
  Returns the entity's size.
  Used for damage calculations and some status effects.
  """
  @callback get_size(state :: any()) :: entity_size()

  @doc """
  Returns the entity's complete stats for all calculations.
  Should return a map with all stats needed for status effects and formulas.
  For units using the common Stats structure, use Stats.to_formula_map/1.
  """
  @callback get_stats(state :: any()) :: map()

  @doc """
  Returns complete entity information for status calculations.
  This is a convenience function that combines all entity properties.
  """
  @callback get_entity_info(state :: any()) :: map()

  @doc """
  Returns the unique identifier for this unit instance.
  This is the ID used to track this specific entity in the game world.
  """
  @callback get_unit_id(state :: any()) :: integer()

  @doc """
  Returns the type of this unit.
  Common types: :player, :mob, :npc, :pet, :homunculus, :mercenary
  """
  @callback get_unit_type(state :: any()) :: atom()

  @doc """
  Returns the process PID for units that have GenServer processes.
  Returns nil for units that don't have an associated process.
  """
  @callback get_process_pid(state :: any()) :: pid() | nil

  @doc """
  Optional: Returns custom immunities for this specific entity.
  Can be used for special NPCs or quest-related immunities.
  """
  @callback get_custom_immunities(state :: any()) :: [atom()]

  @doc """
  Converts a unit state to a standardized Combatant struct for combat operations.

  This callback extracts all necessary combat information from the unit's
  state and packages it into the unified Combatant format.

  ## Returns
    - Combatant struct with all combat-relevant data
  """
  @callback to_combatant(state :: any()) :: Aesir.ZoneServer.Mmo.Combat.Combatant.t()

  @optional_callbacks [get_custom_immunities: 1, get_process_pid: 1, to_combatant: 1]

  @doc """
  Helper function to build standard entity info map from an entity module.
  """
  @spec build_entity_info(module(), any()) :: map()
  def build_entity_info(entity_module, entity_state) when is_atom(entity_module) do
    {element, element_level} = entity_module.get_element(entity_state)

    base_info = %{
      unit_id: entity_module.get_unit_id(entity_state),
      unit_type: entity_module.get_unit_type(entity_state),
      race: entity_module.get_race(entity_state),
      element: element,
      element_level: element_level,
      boss_flag: entity_module.is_boss?(entity_state),
      size: entity_module.get_size(entity_state),
      stats: entity_module.get_stats(entity_state)
    }

    # Add process PID if the callback is implemented
    base_info =
      if function_exported?(entity_module, :get_process_pid, 1) do
        Map.put(base_info, :process_pid, entity_module.get_process_pid(entity_state))
      else
        base_info
      end

    # Add custom immunities if the callback is implemented
    if function_exported?(entity_module, :get_custom_immunities, 1) do
      Map.put(base_info, :custom_immunities, entity_module.get_custom_immunities(entity_state))
    else
      base_info
    end
  end
end
