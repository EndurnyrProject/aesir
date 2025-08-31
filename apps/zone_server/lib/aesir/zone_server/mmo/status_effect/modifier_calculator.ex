defmodule Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator do
  @moduledoc """
  Calculates and aggregates status effect modifiers.

  This module is responsible for evaluating status effect modifiers,
  which are the numerical effects applied to character stats like
  strength, defense, attack power, etc.

  It handles both static modifiers and dynamic formulas, calculating
  their values based on the context of the status effect.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.PhaseManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @doc """
  Get calculated modifiers for all active statuses on a target.

  ## Parameters
    - unit_type: The type of the unit (:player, :npc, :monster, etc.)
    - unit_id: The ID of the target entity
    
  ## Returns
    - Map of modifier keys to calculated values
  """
  @spec get_all_modifiers(atom(), integer()) :: map()
  def get_all_modifiers(unit_type, unit_id) do
    statuses = StatusStorage.get_unit_statuses(unit_type, unit_id)

    Enum.reduce(statuses, %{}, fn status, acc ->
      case Registry.get_definition(status.type) do
        definition when definition != nil ->
          current_def = PhaseManager.get_current_phase_definition(definition, status)
          context = ContextBuilder.build_context(unit_type, unit_id, status.source_id, status)
          compiled_modifiers = calculate_modifiers(current_def[:modifiers], context, status)

          merge_modifiers(acc, compiled_modifiers)

        _ ->
          acc
      end
    end)
  end

  @doc """
  Calculate modifiers based on provided definition and context.

  ## Parameters
    - modifiers: Map of modifier keys to formula or static values
    - context: Execution context with stats and values
    - status: The status effect instance
    
  ## Returns
    - Map of calculated modifier values
  """
  @spec calculate_modifiers(map() | nil, map(), map()) :: map()
  def calculate_modifiers(nil, _context, _status), do: %{}

  def calculate_modifiers(modifiers, context, status) do
    Enum.map(modifiers, fn {key, value} ->
      {key, evaluate_modifier_value(value, context, status)}
    end)
    |> Map.new()
  end

  @doc """
  Evaluate a single modifier value which may be a formula or static value.

  ## Parameters
    - value: The modifier value (formula string or static value)
    - context: Execution context with stats and values
    - status: The status effect instance
    
  ## Returns
    - The calculated value
  """
  @spec evaluate_modifier_value(any(), map(), map()) :: number() | boolean()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def evaluate_modifier_value(formula, context, status) when is_binary(formula) do
    # Handle direct references to val1-val4
    cond do
      formula == "val1" ->
        status.val1

      formula == "val2" ->
        status.val2

      formula == "val3" ->
        status.val3

      formula == "val4" ->
        status.val4

      formula == "-val1" ->
        -status.val1

      formula == "-val2" ->
        -status.val2

      formula == "-val3" ->
        -status.val3

      formula == "-val4" ->
        -status.val4

      true ->
        # For more complex formulas, use the formula compiler
        compiled_fn = FormulaCompiler.compile(formula)
        compiled_fn.(context)
    end
  end

  def evaluate_modifier_value(static_value, _context, _status) do
    static_value
  end

  @doc """
  Merge two modifier maps, adding values for the same keys.

  ## Parameters
    - base: Base modifier map
    - new: New modifiers to add
    
  ## Returns
    - Merged modifier map
  """
  @spec merge_modifiers(map(), map()) :: map()
  def merge_modifiers(base, new) do
    Map.merge(base, new, fn _key, v1, v2 ->
      v1 + v2
    end)
  end
end
