defmodule Aesir.ZoneServer.Unit.Player.InventoryView do
  @moduledoc """
  Builds outbound inventory and cart wire messages from server-side item state.

  Mirrors `SkillListView` for the item domain: every builder resolves the item
  database view fields (`type`/`look`) and applies the +2 client index offset so
  the inventory and cart index spaces stay consistent across all messages.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.CartInfo
  alias Aesir.Net.CartItemAdded
  alias Aesir.Net.CartItemRemoved
  alias Aesir.Net.InventoryList
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc """
  Builds an `ItemAdded` for an item that just entered the inventory.

  Replaces the legacy `ZC_ITEM_PICKUP_ACK` success path: `server_index` carries the
  +2 client offset, `cards` collapses the four card slots, `type`/`look` are resolved
  from the item database and `result` is the success code (0).
  """
  @spec item_added(InventoryItem.t(), non_neg_integer()) :: ItemAdded.t()
  def item_added(%InventoryItem{} = item, server_index) do
    %ItemAdded{
      index: PlayerState.client_index(server_index),
      amount: item.amount,
      nameid: item.nameid,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      location: item.equip,
      type: client_type(item.nameid),
      result: 0,
      expire_time: encode_expire_time(item.expire_time),
      look: item_view(item.nameid)
    }
  end

  @doc """
  Builds an `ItemRemoved` for an item that left (or was reduced in) the inventory.

  Replaces the legacy `ZC_DELETE_ITEM_FROM_BODY`: `server_index` carries the +2 client
  offset and `reason` is the rAthena delete-type code (0 = normal removal).
  """
  @spec item_removed(non_neg_integer(), pos_integer(), non_neg_integer()) :: ItemRemoved.t()
  def item_removed(server_index, amount, reason \\ 0) do
    %ItemRemoved{
      index: PlayerState.client_index(server_index),
      amount: amount,
      reason: reason
    }
  end

  @doc """
  Builds the full `InventoryList` dump for an inventory map (sent on map load).

  Collapses the legacy 4-packet inventory dump (ZC_INVENTORY_START/ITEMLIST_NORMAL/
  ITEMLIST_EQUIP/END) into a single InventoryList. Items split by `equip`: 0 ->
  normal (stackable), >0 -> equip (worn), both sorted by the unified server index
  so the client index space (+2 offset) stays collision-free.
  """
  @spec inventory_list(%{non_neg_integer() => InventoryItem.t()}) :: InventoryList.t()
  def inventory_list(inventory) do
    {equipped, stackable} =
      inventory
      |> Enum.sort_by(fn {index, _item} -> index end)
      |> Enum.split_with(fn {_index, item} -> item.equip > 0 end)

    %InventoryList{
      normal: Enum.map(stackable, fn {index, item} -> to_inventory_item(index, item) end),
      equip: Enum.map(equipped, fn {index, item} -> to_inventory_item(index, item) end)
    }
  end

  @doc """
  Builds the full `CartInfo` dump for a cart map (sent on mount/login).

  Mirrors `inventory_list/1` but for the cart: each slot is reused through
  `to_inventory_item/2`, so cart wire items carry the same +2 client index
  offset as inventory items.
  """
  @spec cart_info(%{non_neg_integer() => InventoryItem.t()}) :: CartInfo.t()
  def cart_info(cart) do
    items =
      cart
      |> Enum.sort_by(fn {index, _item} -> index end)
      |> Enum.map(fn {index, item} -> to_inventory_item(index, item) end)

    %CartInfo{items: items}
  end

  @doc """
  Builds a `CartItemAdded` for a cart slot, mirroring `item_added/2`.
  """
  @spec cart_item_added(InventoryItem.t(), non_neg_integer()) :: CartItemAdded.t()
  def cart_item_added(%InventoryItem{} = item, server_index) do
    %CartItemAdded{
      index: PlayerState.client_index(server_index),
      amount: item.amount,
      nameid: item.nameid,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      location: item.equip,
      type: client_type(item.nameid),
      result: 0,
      expire_time: encode_expire_time(item.expire_time),
      look: item_view(item.nameid)
    }
  end

  @doc """
  Builds a `CartItemRemoved` for a cart slot, mirroring `item_removed/3`.
  """
  @spec cart_item_removed(non_neg_integer(), pos_integer(), non_neg_integer()) ::
          CartItemRemoved.t()
  def cart_item_removed(server_index, amount, reason \\ 0) do
    %CartItemRemoved{
      index: PlayerState.client_index(server_index),
      amount: amount,
      reason: reason
    }
  end

  @spec to_inventory_item(non_neg_integer(), InventoryItem.t()) :: Aesir.Net.InventoryItem.t()
  defp to_inventory_item(index, %InventoryItem{} = item) do
    %Aesir.Net.InventoryItem{
      index: PlayerState.client_index(index),
      nameid: item.nameid,
      type: client_type(item.nameid),
      amount: item.amount,
      location: item.equip,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      expire_time: encode_expire_time(item.expire_time),
      bind_on_equip: item.bound,
      favorite: item.favorite == 1,
      look: item_view(item.nameid)
    }
  end

  @spec client_type(integer()) :: non_neg_integer()
  defp client_type(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{type: type}} -> ClientItemType.to_client_type(type)
      {:error, :item_not_found} -> ClientItemType.to_client_type(:etc)
    end
  end

  @spec item_view(integer()) :: integer()
  defp item_view(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      # Weapons carry their sprite as the weapon class (derived from the subtype)
      # unless the item sets an explicit `view` for a unique sprite. Mirrors
      # `Stats.weapon_view/1` so the inventory `look` matches the appearance view.
      {:ok, %{type: :weapon, view: 0, subtype: subtype}} -> WeaponTypes.get_weapon_id(subtype)
      {:ok, %{view: view}} -> view
      {:error, :item_not_found} -> 0
    end
  end

  @spec encode_expire_time(NaiveDateTime.t() | nil) :: non_neg_integer()
  defp encode_expire_time(nil), do: 0

  defp encode_expire_time(datetime) do
    datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end
end
