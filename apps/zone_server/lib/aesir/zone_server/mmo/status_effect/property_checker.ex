defmodule Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker do
  @moduledoc """
  Provides utilities to check status effect properties.

  This module contains functions to check if a status effect has specific
  properties like being a buff/debuff, preventing movement, etc.

  It centralizes all property-related queries to make the code more maintainable
  and reduce duplication.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  @doc """
  Check if a status has a specific property.

  ## Parameters
    - status_id: The ID of the status effect
    - property: The property to check for
    
  ## Returns
    - true if the status has the property, false otherwise
  """
  @spec has_property?(atom(), atom()) :: boolean()
  def has_property?(status_id, property) do
    case Registry.get_definition(status_id) do
      %{properties: props} when is_list(props) -> property in props
      _ -> false
    end
  end

  @doc """
  Check if a status is a debuff.

  ## Parameters
    - status_id: The ID of the status effect
    
  ## Returns
    - true if the status is a debuff, false otherwise
  """
  @spec debuff?(atom()) :: boolean()
  def debuff?(status_id) do
    has_property?(status_id, :debuff)
  end

  @doc """
  Check if a status is a buff.

  ## Parameters
    - status_id: The ID of the status effect
    
  ## Returns
    - true if the status is a buff, false otherwise
  """
  @spec buff?(atom()) :: boolean()
  def buff?(status_id) do
    not debuff?(status_id)
  end

  @doc """
  Check if a status prevents movement.

  ## Parameters
    - status_id: The ID of the status effect
    
  ## Returns
    - true if the status prevents movement, false otherwise
  """
  @spec prevents_movement?(atom()) :: boolean()
  def prevents_movement?(status_id) do
    has_property?(status_id, :prevents_movement)
  end

  @doc """
  Check if a status prevents using skills.

  ## Parameters
    - status_id: The ID of the status effect
    
  ## Returns
    - true if the status prevents skills, false otherwise
  """
  @spec prevents_skills?(atom()) :: boolean()
  def prevents_skills?(status_id) do
    has_property?(status_id, :prevents_skills)
  end

  @doc """
  Check if a status prevents attacking.

  ## Parameters
    - status_id: The ID of the status effect
    
  ## Returns
    - true if the status prevents attacking, false otherwise
  """
  @spec prevents_attack?(atom()) :: boolean()
  def prevents_attack?(status_id) do
    has_property?(status_id, :prevents_attack)
  end

  @doc """
  Get all properties of a status.

  ## Parameters
    - status_id: The ID of the status effect
    
  ## Returns
    - List of properties, or empty list if none defined
  """
  @spec get_properties(atom()) :: list(atom())
  def get_properties(status_id) do
    case Registry.get_definition(status_id) do
      %{properties: props} when is_list(props) -> props
      _ -> []
    end
  end

  @doc """
  Check if a target is immune to a status effect.

  ## Parameters
    - target_id: The ID of the target entity
    - definition: The status effect definition
    
  ## Returns
    - true if immune, false otherwise
  """
  @spec check_immunity(integer(), map()) :: boolean()
  def check_immunity(_target_id, definition) do
    # TODO: Check target properties against immunity list
    _ = definition[:immunity]
    false
  end

  @doc """
  Check if a condition is met in the given context.

  ## Parameters
    - condition: The condition to check (function, map, or nil)
    - context: The execution context
    
  ## Returns
    - true if the condition is met, false otherwise
  """
  @spec check_condition(function() | map() | nil, map()) :: boolean()
  def check_condition(nil, _context), do: true

  def check_condition(%{element: element}, context) do
    context[:damage_info][:element] == element
  end

  def check_condition(condition_fn, context) when is_function(condition_fn) do
    condition_fn.(context) != 0
  end

  def check_condition(_, _), do: true
end
