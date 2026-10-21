defmodule Aesir.ZoneServer.Guild.Storage do
  @moduledoc """
  Pure domain core for a guild's shared storage container.

  Capacity and deposit eligibility have no side effects; item movement delegates
  to the shared container core.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.ItemContainer

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

  @doc """
  Adds `amount` copies of `item` with the guild storage recipe
  (`ItemContainer.put/6`) into a storage of `capacity` slots.

  Refusals are `:invalid`, `:storage_full` (the stack limit), `:restricted`
  (the item or a slotted card may not enter guild storage, or it expires),
  `:bound` (account bound, or bound past the guild) and `:storage_full` (a
  full stack or no free slot), in that order.
  """
  @spec add(t(), ItemDefinition.t(), integer(), pos_integer(), InventoryItem.t()) ::
          ItemContainer.op_result()
  def add(storage, %ItemDefinition{} = item_def, amount, capacity, %InventoryItem{} = item) do
    room = %{capacity: capacity, weight: :infinity}
    ItemContainer.put(storage, :guild_storage, item_def, item, amount, room)
  end

  @doc "Removes an amount from the item at a storage index."
  @spec remove(t(), non_neg_integer(), pos_integer()) :: ItemContainer.op_result()
  defdelegate remove(storage, index, amount), to: ItemContainer

  @doc """
  Returns whether an inventory item may leave for guild storage: a worn item
  may not. What guild storage accepts is decided by `add/5`.
  """
  @spec depositable(InventoryItem.t()) :: :ok | {:error, :item_equipped}
  def depositable(%InventoryItem{equip: 0, equip_switch: 0}), do: :ok
  def depositable(%InventoryItem{}), do: {:error, :item_equipped}
end
