defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.ModifyStat do
  @moduledoc """
  Modify stat action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  require Logger

  @impl true
  def execute(target_id, params, state, context) do
    stat = params[:stat]

    value =
      case params do
        %{formula_fn: formula_fn} when is_function(formula_fn) ->
          formula_fn.(context)

        %{value: val} ->
          val

        %{amount: amount} ->
          amount

        _ ->
          0
      end

    # TODO: Actually modify the stat through player session
    Logger.debug("Modifying stat #{stat} by #{value} for target #{target_id}")

    {:ok, state}
  end
end
