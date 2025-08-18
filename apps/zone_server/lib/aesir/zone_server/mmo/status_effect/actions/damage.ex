defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.Damage do
  @moduledoc """
  Damage action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  require Logger

  @impl true
  def execute(target_id, params, state, context) do
    damage = calculate_damage(params, context)
    element = params[:element] || :neutral

    # TODO: Actually deal damage through combat system
    Logger.debug("Dealing #{damage} #{element} damage to target #{target_id}")

    # For now, just log
    # Combat.deal_damage(target_id, damage, element)

    {:ok, state}
  end

  defp calculate_damage(%{formula_fn: formula_fn}, context) when is_function(formula_fn) do
    damage = formula_fn.(context)

    # Apply min/max bounds if specified
    damage = if context[:min], do: max(damage, context[:min]), else: damage
    damage = if context[:max], do: min(damage, context[:max]), else: damage

    trunc(damage)
  end

  defp calculate_damage(%{amount: amount}, _context) when is_number(amount) do
    trunc(amount)
  end

  defp calculate_damage(_, _), do: 0
end
