defmodule Aesir.ZoneServer.Unit.Rental do
  @moduledoc """
  Policy for time-limited rental inventory items.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @rentable_types [:weapon, :armor, :pet_armor, :shadow_gear]

  @doc """
  Returns whether an item has a rental expiry.
  """
  @spec rented?(InventoryItem.t()) :: boolean()
  def rented?(%InventoryItem{expire_time: nil}), do: false
  def rented?(%InventoryItem{}), do: true

  @doc """
  Returns whether an item's rental expiry has passed.
  """
  @spec expired?(InventoryItem.t(), NaiveDateTime.t()) :: boolean()
  def expired?(%InventoryItem{expire_time: nil}, _now), do: false

  def expired?(%InventoryItem{expire_time: expire_time}, now) do
    NaiveDateTime.compare(expire_time, now) != :gt
  end

  @doc """
  Returns whether an item may leave inventory through a player-initiated transfer.
  """
  @spec transferable?(InventoryItem.t()) :: boolean()
  def transferable?(item), do: not rented?(item)

  @doc """
  Returns whether an item definition may be granted as a rental.
  """
  @spec rentable_type?(ItemDefinition.t()) :: boolean()
  def rentable_type?(%ItemDefinition{type: type}), do: type in @rentable_types

  @doc """
  Returns the rental expiry after a duration in seconds.
  """
  @spec expire_at(pos_integer(), NaiveDateTime.t()) :: NaiveDateTime.t()
  def expire_at(seconds, now), do: NaiveDateTime.add(now, seconds, :second)
end
