defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.Heal do
  @moduledoc """
  Heal action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  require Logger

  @impl true
  def execute(target_id, params, state, context) do
    amount = calculate_heal(params, context)
    heal_type = params[:heal_type] || :hp

    # TODO: Actually heal through combat/healing system
    Logger.debug("Healing #{amount} #{heal_type} to target #{target_id}")

    # For now, just log
    # case heal_type do
    #   :hp -> Healing.heal_hp(target_id, amount)
    #   :sp -> Healing.heal_sp(target_id, amount)
    # end

    {:ok, state}
  end

  defp calculate_heal(%{formula_fn: formula_fn}, context) when is_function(formula_fn) do
    amount = formula_fn.(context)

    # Apply min/max bounds if specified
    amount = if context[:min], do: max(amount, context[:min]), else: amount
    amount = if context[:max], do: min(amount, context[:max]), else: amount

    trunc(amount)
  end

  defp calculate_heal(%{amount: amount}, _context) when is_number(amount) do
    trunc(amount)
  end

  defp calculate_heal(_, _), do: 0
end
