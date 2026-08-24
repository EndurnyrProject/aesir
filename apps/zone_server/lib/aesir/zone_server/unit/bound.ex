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

  Personal storage accepts unbound and account-bound items; guild storage uses
  the inverse account/guild-bound policy in `guild_storable?/1`.
  """
  @spec storable?(InventoryItem.t()) :: boolean()
  def storable?(%InventoryItem{bound: bound}), do: bound in [0, 1]

  @doc """
  Returns whether an item may enter guild storage.

  Unlike personal storage, guild storage accepts guild-bound items and rejects
  account-bound items.
  """
  @spec guild_storable?(InventoryItem.t()) :: boolean()
  def guild_storable?(%InventoryItem{bound: bound}), do: bound in [0, 2]
end
