defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.IncrementState do
  @moduledoc """
  Increment instance state action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  require Logger

  @impl true
  def execute(_target_id, params, state, context) do
    key = String.to_atom(to_string(params[:key]))

    increment =
      case params do
        %{formula_fn: formula_fn} when is_function(formula_fn) ->
          formula_fn.(context)

        %{amount: amount} ->
          amount

        _ ->
          1
      end

    current_value = Map.get(state, key, 0)
    new_value = current_value + increment

    new_state = Map.put(state, key, new_value)

    Logger.debug("Incrementing state #{key}: #{current_value} -> #{new_value}")

    {:ok, new_state}
  end
end
