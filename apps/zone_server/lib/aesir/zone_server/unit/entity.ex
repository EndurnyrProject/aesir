defmodule Aesir.ZoneServer.Unit.Entity do
  @moduledoc """
  Behaviour for game entities (players, monsters, NPCs) that defines
  common properties and functions for status effect resistance and immunity.

  This behaviour ensures all entities provide the necessary information
  for status effect calculations and other game mechanics.
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
  Returns the entity's current stats.
  Should include at minimum: vit, int, dex, luk, mdef
  """
  @callback get_stats(state :: any()) :: map()

  @doc """
  Returns complete entity information for status calculations.
  This is a convenience function that combines all entity properties.
  """
  @callback get_entity_info(state :: any()) :: map()

  @doc """
  Optional: Returns custom immunities for this specific entity.
  Can be used for special NPCs or quest-related immunities.
  """
  @callback get_custom_immunities(state :: any()) :: [atom()]

  @optional_callbacks [get_custom_immunities: 1]

  @doc """
  Helper function to build standard entity info map from an entity module.
  """
  @spec build_entity_info(module(), any()) :: map()
  def build_entity_info(entity_module, entity_state) when is_atom(entity_module) do
    {element, element_level} = entity_module.get_element(entity_state)

    base_info = %{
      race: entity_module.get_race(entity_state),
      element: element,
      element_level: element_level,
      boss_flag: entity_module.is_boss?(entity_state),
      size: entity_module.get_size(entity_state),
      stats: entity_module.get_stats(entity_state)
    }

    # Add custom immunities if the callback is implemented
    if function_exported?(entity_module, :get_custom_immunities, 1) do
      Map.put(base_info, :custom_immunities, entity_module.get_custom_immunities(entity_state))
    else
      base_info
    end
  end
end
