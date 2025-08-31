defmodule Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder do
  @moduledoc """
  Creates execution contexts for status effect formulas and actions.

  This module provides functions to build and enrich execution contexts with
  the data needed by status effect formulas, conditions, and actions.
  It abstracts away player stats retrieval and context construction logic.

  The context includes:
  - Target and caster stats (str, agi, vit, etc.)
  - State data from the status effect instance
  - Values from the status effect (val1-val4)
  - Additional context data for specific events (damage, healing, etc.)
  """
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Builds a context map for status effect execution.

  The context includes target stats, caster stats (if available),
  and status effect state and values.

  ## Parameters
    - unit_type: The type of the unit (:player, :npc, :monster, etc.)
    - unit_id: The ID of the target entity
    - caster_id: The ID of the caster entity (or nil)
    - instance: The StatusEntry struct representing the status effect instance
    
  ## Returns
    - A map containing all the context needed for formula evaluation
  """
  @spec build_context(atom(), integer(), integer() | nil, StatusEntry.t()) :: map()
  def build_context(unit_type, unit_id, caster_id, %StatusEntry{} = instance) do
    # Get the unit stats for the target
    target_stats = get_unit_stats(unit_type, unit_id)

    # Get the caster stats if available
    # Note: We assume caster is same type as target for now
    # This could be enhanced to track caster type separately
    caster_stats =
      if caster_id && caster_id != unit_id do
        get_unit_stats(unit_type, caster_id)
      else
        # If no caster_id or it's the same as target, use empty map
        %{}
      end

    %{
      # Include IDs for custom functions to access
      target_id: unit_id,
      caster_id: caster_id,
      # Stats for formula calculations
      target: target_stats,
      caster: caster_stats,
      state: instance.state || %{},
      val1: instance.val1 || 0,
      val2: instance.val2 || 0,
      val3: instance.val3 || 0,
      val4: instance.val4 || 0
    }
  end

  @doc """
  Enhances an existing context with damage information.

  ## Parameters
    - context: The existing context map
    - damage_info: Map containing damage information (damage, element, type)
    
  ## Returns
    - The enhanced context with damage information
  """
  @spec add_damage_info(map(), map()) :: map()
  def add_damage_info(context, damage_info) do
    Map.put(context, :damage_info, damage_info)
  end

  @doc """
  Get unit stats from UnitRegistry.

  ## Parameters
    - unit_type: The type of the unit
    - unit_id: The ID of the unit
    
  ## Returns
    - Map of unit stats
    
  ## Raises
    - RuntimeError if unit not found or stats can't be retrieved
  """
  @spec get_unit_stats(atom(), integer()) :: map()
  def get_unit_stats(unit_type, unit_id) do
    case UnitRegistry.get_unit_info(unit_type, unit_id) do
      {:ok, entity_info} ->
        # Trust the entity to provide complete stats
        # The Entity behavior contract requires get_stats to return all needed values
        entity_info[:stats] || raise "Entity #{unit_type} #{unit_id} returned nil stats"

      {:error, :not_found} ->
        # Unit not found - critical error
        raise "#{unit_type} #{unit_id} not found in UnitRegistry"
    end
  end
end
