defmodule Aesir.ZoneServer.Guild.Storage do
  @moduledoc """
  Pure domain core for a guild's shared storage container.

  Capacity and deposit eligibility have no side effects; item movement delegates
  to the shared container core.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Bound
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Rental

  @guild_storage 10_016
  @slots_per_level 100

  @typedoc "Guild storage keyed by stable session index."
  @type t :: %{non_neg_integer() => InventoryItem.t()}

  @doc "Returns 0 unlearned, otherwise 100 times the learned level plus one."
  @spec capacity(State.t()) :: non_neg_integer()
  def capacity(%State{} = guild) do
    case State.skill_level(guild, @guild_storage) do
      0 -> 0
      level -> @slots_per_level * (level + 1)
    end
  end

  @doc "Adds an item while preserving its attributes and stacking rules."
  @spec add(t(), ItemDefinition.t(), pos_integer(), pos_integer(), InventoryItem.t()) ::
          ItemContainer.op_result()
  defdelegate add(storage, item_def, amount, capacity, item),
    to: ItemContainer,
    as: :add_preserving

  @doc "Removes an amount from the item at a storage index."
  @spec remove(t(), non_neg_integer(), pos_integer()) :: ItemContainer.op_result()
  defdelegate remove(storage, index, amount), to: ItemContainer

  @doc "Returns whether an item may be deposited into guild storage."
  @spec depositable(InventoryItem.t(), ItemDefinition.t()) :: :ok | {:error, atom()}
  def depositable(%InventoryItem{} = item, %ItemDefinition{} = item_def) do
    cond do
      item.equip != 0 or item.equip_switch != 0 -> {:error, :item_equipped}
      not Bound.guild_storable?(item) -> {:error, :not_storable}
      not Rental.transferable?(item) -> {:error, :rental}
      item_def.no_guild_storage -> {:error, :no_guild_storage}
      card_blocked?(item) -> {:error, :no_guild_storage}
      true -> :ok
    end
  end

  @spec card_blocked?(InventoryItem.t()) :: boolean()
  defp card_blocked?(%InventoryItem{} = item) do
    item
    |> InventoryItem.cards()
    |> Enum.reject(&(&1 in [0, nil]))
    # Unknown card ids are unrestricted so custom or corrupted items remain depositable.
    |> Enum.any?(fn nameid ->
      match?(
        {:ok, %ItemDefinition{no_guild_storage: true}},
        ItemManagement.get_item_by_id(nameid)
      )
    end)
  end
end
