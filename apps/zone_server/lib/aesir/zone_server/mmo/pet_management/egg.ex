defmodule Aesir.ZoneServer.Mmo.PetManagement.Egg do
  @moduledoc "Encodes pet identity and intimacy in inventory egg cards."

  import Bitwise

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory

  @pet_marker 256

  @typedoc "The card words and identification flag written for a new egg."
  @type attrs :: %{card0: 256, card1: 0..65_535, card2: 0..65_535, card3: 0..11, identify: 1}

  @typep card_words :: %{
           required(:card0) => integer(),
           required(:card1) => integer(),
           required(:card2) => integer(),
           optional(atom()) => term()
         }

  @doc "Builds the card attributes for a newly created pet egg."
  @spec egg_attrs(pos_integer(), non_neg_integer()) :: attrs()
  def egg_attrs(pet_id, intimate) do
    %{
      card0: @pet_marker,
      card1: pet_id &&& 0xFFFF,
      card2: pet_id >>> 16 &&& 0xFFFF,
      card3: card3(0, intimate),
      identify: 1
    }
  end

  @doc "Reads the pet ID from an egg, or nil for another item."
  @spec pet_id(InventoryItem.t() | card_words()) :: integer() | nil
  def pet_id(%{card0: @pet_marker, card1: low, card2: high}), do: low ||| high <<< 16
  def pet_id(_item), do: nil

  @doc "Checks whether an egg is hatched."
  @spec hatched?(InventoryItem.t()) :: boolean()
  def hatched?(%{card0: @pet_marker, attribute: 1}), do: true
  def hatched?(_item), do: false

  @doc "Encodes the rename flag and intimacy grade."
  @spec card3(0 | 1, integer()) :: 0..11
  def card3(rename_flag, intimate) do
    grade =
      cond do
        intimate < 100 -> 2
        intimate < 250 -> 4
        intimate < 750 -> 6
        intimate < 910 -> 8
        intimate <= 1000 -> 10
        true -> 0
      end

    grade ||| rename_flag
  end

  @doc "Finds the egg for a pet in an inventory."
  @spec find(Inventory.t(), pos_integer()) :: {:ok, InventoryItem.t()} | :error
  def find(inventory, pet_id) do
    case Enum.find(inventory, fn {_index, item} -> pet_id(item) == pet_id end) do
      {_index, item} -> {:ok, item}
      nil -> :error
    end
  end
end
