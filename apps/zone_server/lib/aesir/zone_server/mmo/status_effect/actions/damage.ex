defmodule Aesir.ZoneServer.Mmo.StatusEffect.Actions.Damage do
  @moduledoc """
  Damage action for status effects.
  """

  @behaviour Aesir.ZoneServer.Mmo.StatusEffect.Action

  require Logger

  alias Aesir.ZoneServer.Mmo.Combat

  @impl true
  def execute(target_id, params, state, context) do
    damage = calculate_damage(params, context)
    element = params[:element] || :neutral

    # Deal damage through combat system
    Logger.debug("Status effect dealing #{damage} #{element} damage to target #{target_id}")

    case Combat.deal_damage(target_id, damage, element, :status_effect) do
      :ok ->
        Logger.debug("Status effect damage applied successfully")

      {:error, reason} ->
        Logger.warning("Failed to apply status effect damage: #{reason}")
    end

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
