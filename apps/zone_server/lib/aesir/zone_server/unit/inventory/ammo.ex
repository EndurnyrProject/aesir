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
  Checks a skill's cast-end ammunition requirement.

  The ammo slot must hold an item whose subtype is one of `allowed` and whose
  stack holds at least `needed` units. A missing slot, an unknown item and a
  foreign subtype refuse with `{:error, :no_ammo}`, the reference's no-ammo
  failure; a short stack refuses with the same reason, though the reference
  names its own message for a short bullet, grenade, shell or kunai stack,
  which the wire protocol does not distinguish yet.
  """
  @spec check(Inventory.t(), [atom()], pos_integer()) :: :ok | {:error, :no_ammo}
  def check(inventory, allowed, needed) when is_map(inventory) do
    with {:ok, row, definition} <- equipped_ammo(inventory),
         true <- row.amount >= needed and definition.subtype in allowed do
      :ok
    else
      _refused -> {:error, :no_ammo}
    end
  end

  @doc """
  Removes `amount` units from the equipped ammo stack.

  Returns `{:ok, new_inventory, change}` (the slot is dropped when the stack
  reaches zero) or `{:error, :no_ammo}` when nothing is equipped in the ammo
  slot, and `{:error, :insufficient_amount}` when the stack is shorter than
  `amount`.
  """
  @spec consume(Inventory.t(), pos_integer()) :: Inventory.op_result()
  def consume(inventory, amount) when is_map(inventory) do
    case equipped_ammo_index(inventory) do
      nil -> {:error, :no_ammo}
      index -> Inventory.remove(inventory, index, amount)
    end
  end

  @doc "Removes one unit from the equipped ammo stack, as a basic attack does."
  @spec consume_one(Inventory.t()) :: Inventory.op_result()
  def consume_one(inventory), do: consume(inventory, 1)
end
