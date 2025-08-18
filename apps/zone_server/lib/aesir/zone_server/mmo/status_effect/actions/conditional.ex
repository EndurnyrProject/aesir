defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.Conditional do
  @moduledoc """
  Conditional action for status effects.

  Evaluates a condition and executes either the 'then' or 'else' branch actions.
  Delegates action execution back to the Interpreter to avoid code duplication.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter

  @impl true
  def execute(target_id, params, state, context) do
    condition_result = evaluate_condition(params[:condition], context)

    actions =
      if condition_result do
        params[:then_actions] || []
      else
        params[:else_actions] || []
      end

    # Execute the selected branch actions
    execute_actions(actions, target_id, state, context)
  end

  defp evaluate_condition(condition_fn, context) when is_function(condition_fn) do
    condition_fn.(context) != 0
  end

  defp evaluate_condition(_, _), do: false

  defp execute_actions([], _target_id, state, _context), do: {:ok, state}

  defp execute_actions(actions, target_id, state, context) do
    Enum.reduce_while(actions, {:ok, state}, fn action, {:ok, current_state} ->
      case Interpreter.execute_single_action(action, target_id, current_state, context) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        :remove -> {:halt, :remove}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
