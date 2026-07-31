defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.Anvil do
  @moduledoc """
  Selects the highest forge bonus from anvils carried in an inventory.
  """

  alias Aesir.ZoneServer.Unit.Inventory

  @bonuses %{986 => 0, 987 => 250, 988 => 500, 989 => 1000}

  @doc """
  Returns the highest bonus provided by an anvil held in `inventory`.
  """
  @spec best(Inventory.t()) :: non_neg_integer()
  def best(inventory) when is_map(inventory) do
    Enum.reduce(@bonuses, 0, fn {item_id, bonus}, highest_bonus ->
      if Inventory.held_amount(inventory, item_id) > 0,
        do: max(highest_bonus, bonus),
        else: highest_bonus
    end)
  end
end
