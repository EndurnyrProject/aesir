defmodule Aesir.ZoneServer.Unit.Bound do
  @moduledoc """
  Transfer policy for bound inventory items.
  """

  alias Aesir.Commons.Models.InventoryItem

  @doc """
  Returns whether an item may be transferred to another player.
  """
  @spec transferable?(InventoryItem.t()) :: boolean()
  def transferable?(%InventoryItem{bound: 0}), do: true
  def transferable?(%InventoryItem{}), do: false

  @doc """
  Returns whether an item may be sold to an NPC.
  """
  @spec sellable?(InventoryItem.t()) :: boolean()
  def sellable?(%InventoryItem{} = item), do: transferable?(item)

  @doc """
  Returns whether an item may be listed for vending.
  """
  @spec vendable?(InventoryItem.t()) :: boolean()
  def vendable?(%InventoryItem{} = item), do: transferable?(item)

  @doc """
  Returns whether an item may enter personal storage.
  """
  @spec storable?(InventoryItem.t()) :: boolean()
  def storable?(%InventoryItem{bound: bound}), do: bound in [0, 1]
end
