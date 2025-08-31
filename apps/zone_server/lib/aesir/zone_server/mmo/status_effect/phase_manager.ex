defmodule Aesir.ZoneServer.Mmo.StatusEffect.PhaseManager do
  @moduledoc """
  Manages phase transitions and phase-related logic for status effects.

  Some status effects in Ragnarok Online have multiple phases with different
  behaviors (e.g., Poison can have different damage amounts in different phases).
  This module handles:

  - Tracking the current phase of a status effect
  - Managing transitions between phases
  - Providing the appropriate definition for the current phase
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.FormulaCompiler
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @doc """
  Check for phase transitions based on elapsed time.

  ## Parameters
    - instance: The StatusEntry struct
    - definition: The status effect definition
    - context: The execution context
    
  ## Returns
    - Updated StatusEntry with potentially new phase
  """
  @spec check_phase_transition(StatusEntry.t(), map(), map()) :: StatusEntry.t()
  # credo:disable-for-next-line Credo.Check.Refactor.Nesting
  def check_phase_transition(instance, definition, _context) do
    case {instance.phase, definition[:phases]} do
      {nil, _} ->
        instance

      {_, nil} ->
        instance

      {current_phase, phases} ->
        current_def = phases[current_phase]

        if current_def[:duration] do
          elapsed = System.system_time(:millisecond) - instance.started_at

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if elapsed >= current_def[:duration] && current_def[:next] do
            %{instance | phase: current_def[:next]}
          else
            instance
          end
        else
          instance
        end
    end
  end

  @doc """
  Get the definition for the current phase or the base definition.

  ## Parameters
    - definition: The status effect definition
    - instance: The StatusEntry struct
    
  ## Returns
    - Definition map for the current phase (or base definition if no phase)
  """
  @spec get_current_phase_definition(map(), StatusEntry.t()) :: map()
  def get_current_phase_definition(definition, instance) do
    case {instance.phase, definition[:phases]} do
      {nil, _} -> definition
      {_, nil} -> definition
      {phase, phases} -> Map.merge(definition, phases[phase] || %{})
    end
  end

  @doc """
  Calculate the duration of a status effect.

  ## Parameters
    - definition: The status effect definition
    - instance: The StatusEntry struct
    - context: The execution context
    
  ## Returns
    - Duration in milliseconds
  """
  @spec calculate_duration(map(), StatusEntry.t(), map()) :: integer()
  def calculate_duration(definition, instance, context) do
    case definition[:duration] do
      nil ->
        instance.tick || 0

      formula when is_binary(formula) ->
        compiled_fn = FormulaCompiler.compile(formula)
        trunc(compiled_fn.(context))

      duration ->
        duration
    end
  end

  @doc """
  Calculate the base duration of a status effect without context.
  Used for resistance calculations before the full context is available.

  ## Parameters
    - definition: The status effect definition
    
  ## Returns
    - Base duration in milliseconds, defaults to 10_000ms if not specified
  """
  @spec calculate_base_duration(map()) :: integer()
  def calculate_base_duration(definition) do
    case definition[:duration] do
      # Default 10 seconds
      nil -> 10_000
      duration when is_integer(duration) -> duration
      # For formulas, use a default since we don't have context yet
      _formula -> 10_000
    end
  end
end
