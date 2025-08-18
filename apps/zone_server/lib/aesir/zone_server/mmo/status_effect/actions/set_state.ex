defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.SetState do
  @moduledoc """
  Set instance state action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  require Logger

  @impl true
  def execute(_target_id, params, state, context) do
    key = params[:key]

    value =
      case params do
        %{formula_fn: formula_fn} when is_function(formula_fn) ->
          formula_fn.(context)

        %{value: val} ->
          val

        _ ->
          0
      end

    new_state = Map.put(state, String.to_atom(to_string(key)), value)

    Logger.debug("Setting state #{key} = #{value}")

    {:ok, new_state}
  end
end
