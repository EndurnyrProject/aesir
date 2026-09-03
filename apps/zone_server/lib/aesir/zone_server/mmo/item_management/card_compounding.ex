defmodule Aesir.ZoneServer.Mmo.ItemManagement.CardCompounding do
  @moduledoc """
  Pure validation and in-memory mutation for compounding cards into equipment.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.ItemContainer

  import Bitwise

  @card_fields [:card0, :card1, :card2, :card3]

  @typedoc "Reason a card source or equipment target cannot be compounded."
  @type reason ::
          :card_not_found
          | :not_a_card
          | :card_source_equipped
          | :target_not_found
          | :same_inventory_slot
          | :not_equipment
          | :target_unidentified
          | :target_equipped
          | :location_mismatch
          | :no_free_socket

  @doc "Returns the sorted inventory indices eligible for the card at `card_index`."
  @spec eligible_targets(Inventory.t(), non_neg_integer()) ::
          {:ok, [non_neg_integer()]} | {:error, reason()}
  def eligible_targets(inventory, card_index) do
    with {:ok, _card, card_definition} <- fetch_card(inventory, card_index) do
      targets =
        inventory
        |> Enum.filter(&eligible_target?(&1, card_index, card_definition))
        |> Enum.map(&elem(&1, 0))
        |> Enum.sort()

      {:ok, targets}
    end
  end

  @doc "Compounds one card into the first free declared socket of an equipment item."
  @spec compound(Inventory.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Inventory.t(), Inventory.change()} | {:error, reason()}
  def compound(inventory, card_index, equipment_index) do
    with {:ok, card, card_definition} <- fetch_card(inventory, card_index),
         {:ok, equipment} <- fetch_target(inventory, equipment_index),
         {:ok, card_field} <-
           validate_target(card_index, card_definition, equipment_index, equipment) do
      {:ok, inventory, _change} = ItemContainer.remove(inventory, card_index, 1)
      equipment = Map.put(equipment, card_field, card.nameid)
      inventory = ItemContainer.put_item(inventory, equipment_index, equipment)

      {:ok, inventory, {:card_compounded, card_index, equipment_index, card_field}}
    end
  end

  defp fetch_card(inventory, card_index) do
    case Map.get(inventory, card_index) do
      %InventoryItem{nameid: nameid, amount: amount} = card
      when is_integer(nameid) and nameid > 0 and is_integer(amount) and amount > 0 ->
        validate_card_definition(card)

      _missing ->
        {:error, :card_not_found}
    end
  end

  defp validate_card_definition(%InventoryItem{} = card) do
    case ItemManagement.get_item_by_id(card.nameid) do
      {:ok, %ItemDefinition{type: :card} = definition} when card.equip == 0 ->
        {:ok, card, definition}

      {:ok, %ItemDefinition{type: :card}} ->
        {:error, :card_source_equipped}

      _not_card ->
        {:error, :not_a_card}
    end
  end

  defp fetch_target(inventory, equipment_index) do
    case Map.get(inventory, equipment_index) do
      %InventoryItem{nameid: nameid, amount: amount} = equipment
      when is_integer(nameid) and nameid > 0 and is_integer(amount) and amount > 0 ->
        {:ok, equipment}

      _missing ->
        {:error, :target_not_found}
    end
  end

  defp validate_target(card_index, _card_definition, card_index, _equipment),
    do: {:error, :same_inventory_slot}

  defp validate_target(
         _card_index,
         %ItemDefinition{} = card_definition,
         _equipment_index,
         %InventoryItem{nameid: nameid, amount: amount} = equipment
       )
       when is_integer(nameid) and nameid > 0 and is_integer(amount) and amount > 0 do
    with {:ok, definition} <- fetch_equipment_definition(equipment),
         :ok <- validate_identified(equipment),
         :ok <- validate_unequipped(equipment),
         :ok <- validate_location(card_definition, definition) do
      first_free_card_field(equipment, definition.slots)
    end
  end

  defp validate_target(_card_index, _card_definition, _equipment_index, _equipment),
    do: {:error, :target_not_found}

  defp eligible_target?({equipment_index, equipment}, card_index, card_definition) do
    match?(
      {:ok, _card_field},
      validate_target(card_index, card_definition, equipment_index, equipment)
    )
  end

  defp fetch_equipment_definition(equipment) do
    case ItemManagement.get_item_by_id(equipment.nameid) do
      {:ok, %ItemDefinition{type: type} = definition} when type in [:weapon, :armor] ->
        {:ok, definition}

      _not_equipment ->
        {:error, :not_equipment}
    end
  end

  defp validate_identified(%InventoryItem{identify: 1}), do: :ok
  defp validate_identified(%InventoryItem{}), do: {:error, :target_unidentified}

  defp validate_unequipped(%InventoryItem{equip: 0}), do: :ok
  defp validate_unequipped(%InventoryItem{}), do: {:error, :target_equipped}

  defp validate_location(card_definition, equipment_definition) do
    card_location = EquipLocation.location_atoms_to_bitmask(card_definition.locations)
    equipment_location = EquipLocation.location_atoms_to_bitmask(equipment_definition.locations)
    left_hand = EquipLocation.location_bit(:left_hand)
    accessories = EquipLocation.location_bit(:both_accessory)
    card_accessory = card_location &&& accessories

    mismatch? =
      (card_location &&& equipment_location) == 0 or
        (equipment_definition.type == :weapon and card_location == left_hand) or
        (equipment_definition.type == :armor and card_accessory != 0 and
           card_accessory != accessories and
           (equipment_location &&& accessories) != card_accessory)

    if mismatch?, do: {:error, :location_mismatch}, else: :ok
  end

  defp first_free_card_field(item, slots) do
    case Enum.find(Enum.take(@card_fields, min(max(slots, 0), 4)), &(Map.fetch!(item, &1) == 0)) do
      nil -> {:error, :no_free_socket}
      card_field -> {:ok, card_field}
    end
  end
end
