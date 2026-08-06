defmodule Aesir.ZoneServer.Unit.Inventory.Ammo do
  @moduledoc """
  Equipped-ammunition queries and consumption for bow/gun attacks and skills.

  An equipped arrow is an inventory item whose `equip` bitmask includes the ammo
  location (`EquipLocation` `:ammo`, `0x008000`); because it is equipped it is
  excluded from the stackable helpers (`Inventory.held_amount/2`,
  `stackable_index/2`), so it is located by its bit instead. Consumption routes
  through `Inventory.remove/3`, which drops the slot when the stack hits zero.
  """

  import Bitwise

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Unit.Inventory

  @doc """
  Returns the inventory index of the item equipped in the ammo slot, or `nil`.
  """
  @spec equipped_ammo_index(Inventory.t()) :: non_neg_integer() | nil
  def equipped_ammo_index(inventory) when is_map(inventory) do
    ammo_bit = EquipLocation.location_bit(:ammo)

    Enum.find_value(inventory, fn {index, %InventoryItem{equip: equip}} ->
      if (equip &&& ammo_bit) != 0, do: index
    end)
  end

  @doc "Returns the equipped ammo row and its item definition without changing inventory."
  @spec equipped_ammo(Inventory.t()) ::
          {:ok, InventoryItem.t(), ItemDefinition.t()} | {:error, :no_ammo | :unknown_item}
  def equipped_ammo(inventory) when is_map(inventory) do
    with index when not is_nil(index) <- equipped_ammo_index(inventory),
         row = Map.fetch!(inventory, index),
         {:ok, definition} <- Items.by_id(row.nameid) do
      {:ok, row, definition}
    else
      nil -> {:error, :no_ammo}
      :error -> {:error, :unknown_item}
    end
  end

  @doc """
  Removes one unit from the equipped ammo stack.

  Returns `{:ok, new_inventory, change}` (the slot is dropped when the stack
  reaches zero) or `{:error, :no_ammo}` when nothing is equipped in the ammo slot.
  """
  @spec consume_one(Inventory.t()) :: Inventory.op_result()
  def consume_one(inventory) when is_map(inventory) do
    case equipped_ammo_index(inventory) do
      nil -> {:error, :no_ammo}
      index -> Inventory.remove(inventory, index, 1)
    end
  end
end
