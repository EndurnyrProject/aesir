defmodule Aesir.ZoneServer.Unit.Trade do
  @moduledoc """
  Trade offer policy for inventory items.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Unit.Bound
  alias Aesir.ZoneServer.Unit.Rental

  @doc """
  Returns whether an item may be offered in a player trade.
  """
  @spec offerable?(InventoryItem.t(), ItemDefinition.t()) ::
          :ok | {:error, :equipped | :bound | :rented | :no_trade | :hatched_egg}
  def offerable?(%InventoryItem{} = item, %ItemDefinition{} = item_definition) do
    cond do
      Egg.hatched?(item) -> {:error, :hatched_egg}
      InventoryItem.equipped?(item) -> {:error, :equipped}
      not Bound.transferable?(item) -> {:error, :bound}
      not Rental.transferable?(item) -> {:error, :rented}
      item_definition.no_trade -> {:error, :no_trade}
      true -> :ok
    end
  end
end
