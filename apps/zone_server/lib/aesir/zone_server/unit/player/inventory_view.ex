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
  alias Aesir.Net.ItemBound
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.StorageItemAdded
  alias Aesir.Net.StorageItemRemoved
  alias Aesir.Net.StorageOpened
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.ItemManagement.CreatorNames
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.Cart.Weight, as: CartWeight
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Storage

  @doc """
  Builds an `ItemAdded` for an item that just entered the inventory.

  Replaces the legacy `ZC_ITEM_PICKUP_ACK` success path: `server_index` carries the
  +2 client offset, `cards` collapses the four card slots, `type`/`look` are resolved
  from the item database and `result` is the success code (0).
  """
  @spec item_added(InventoryItem.t(), non_neg_integer()) :: ItemAdded.t()
  def item_added(%InventoryItem{} = item, server_index) do
    names = CreatorNames.names_for([item])

    struct(
      ItemAdded,
      item_fields(item, names)
      |> Map.merge(%{index: PlayerState.client_index(server_index), result: 0})
    )
  end

  @spec item_bound(non_neg_integer(), non_neg_integer()) :: ItemBound.t()
  def item_bound(server_index, bound) do
    %ItemBound{index: PlayerState.client_index(server_index), bound: to_bound_type(bound)}
  end

  @spec to_bound_type(non_neg_integer()) :: atom()
  defp to_bound_type(0), do: :BOUND_NONE
  defp to_bound_type(1), do: :BOUND_ACCOUNT
  defp to_bound_type(2), do: :BOUND_GUILD
  defp to_bound_type(3), do: :BOUND_PARTY
  defp to_bound_type(4), do: :BOUND_CHAR
  defp to_bound_type(_), do: :BOUND_NONE

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
  Builds the shared inventory-item wire representation for a trade offer.

  `index` is already in the client index space. Partner offer rows use zero
  because their inventory indices have no meaning to this client.
  """
  @spec trade_item(non_neg_integer(), InventoryItem.t(), pos_integer()) ::
          Aesir.Net.InventoryItem.t()
  def trade_item(index, %InventoryItem{} = item, amount) do
    names = CreatorNames.names_for([item])

    struct(
      Aesir.Net.InventoryItem,
      item_fields(%{item | amount: amount}, names)
      |> Map.merge(%{
        index: index,
        bound: to_bound_type(item.bound),
        favorite: item.favorite == 1
      })
    )
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
    items = Enum.sort_by(inventory, fn {index, _item} -> index end)
    names = items |> Enum.map(&elem(&1, 1)) |> CreatorNames.names_for()
    {equipped, stackable} = Enum.split_with(items, fn {_index, item} -> item.equip > 0 end)

    %InventoryList{
      normal: Enum.map(stackable, fn {index, item} -> to_inventory_item(index, item, names) end),
      equip: Enum.map(equipped, fn {index, item} -> to_inventory_item(index, item, names) end)
    }
  end

  @doc """
  Builds the full `CartInfo` dump for a cart map (sent on mount/login).

  Mirrors `inventory_list/1` but for the cart: each slot is reused through
  `to_inventory_item/3`, so cart wire items carry the same +2 client index
  offset as inventory items.
  """
  @spec cart_info(%{non_neg_integer() => InventoryItem.t()}) :: CartInfo.t()
  def cart_info(cart) do
    cart_items = Enum.sort_by(cart, fn {index, _item} -> index end)
    names = cart_items |> Enum.map(&elem(&1, 1)) |> CreatorNames.names_for()
    items = Enum.map(cart_items, fn {index, item} -> to_inventory_item(index, item, names) end)

    %CartInfo{
      items: items,
      current_weight: CartWeight.current_weight(cart),
      max_weight: CartWeight.max_weight()
    }
  end

  @doc """
  Builds a `CartItemAdded` for a cart slot, mirroring `item_added/2`.
  """
  @spec cart_item_added(InventoryItem.t(), non_neg_integer()) :: CartItemAdded.t()
  def cart_item_added(%InventoryItem{} = item, server_index) do
    names = CreatorNames.names_for([item])

    struct(
      CartItemAdded,
      item_fields(item, names)
      |> Map.merge(%{index: PlayerState.client_index(server_index), result: 0})
    )
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

  @doc """
  Builds the full `StorageOpened` dump for a storage map (sent on window open).

  Mirrors `cart_info/1`: each slot reuses `to_inventory_item/3`, so storage wire
  items carry the same +2 client index offset as inventory and cart items.
  """
  @spec storage_opened(%{non_neg_integer() => InventoryItem.t()}) :: StorageOpened.t()
  def storage_opened(storage) do
    storage_items = Enum.sort_by(storage, fn {index, _item} -> index end)
    names = storage_items |> Enum.map(&elem(&1, 1)) |> CreatorNames.names_for()
    items = Enum.map(storage_items, fn {index, item} -> to_inventory_item(index, item, names) end)

    %StorageOpened{capacity: Storage.capacity(), items: items}
  end

  @doc """
  Builds a `StorageItemAdded` for a storage slot, mirroring `cart_item_added/2`.
  """
  @spec storage_item_added(InventoryItem.t(), non_neg_integer()) :: StorageItemAdded.t()
  def storage_item_added(%InventoryItem{} = item, server_index) do
    names = CreatorNames.names_for([item])

    struct(
      StorageItemAdded,
      item_fields(item, names)
      |> Map.merge(%{index: PlayerState.client_index(server_index), result: 0})
    )
  end

  @doc """
  Builds a `StorageItemRemoved` for a storage slot, mirroring `cart_item_removed/3`.
  """
  @spec storage_item_removed(non_neg_integer(), pos_integer(), non_neg_integer()) ::
          StorageItemRemoved.t()
  def storage_item_removed(server_index, amount, reason \\ 0) do
    %StorageItemRemoved{
      index: PlayerState.client_index(server_index),
      amount: amount,
      reason: reason
    }
  end

  @spec to_inventory_item(non_neg_integer(), InventoryItem.t(), %{non_neg_integer() => String.t()}) ::
          Aesir.Net.InventoryItem.t()
  defp to_inventory_item(index, %InventoryItem{} = item, names) do
    struct(
      Aesir.Net.InventoryItem,
      item_fields(item, names)
      |> Map.merge(%{
        index: PlayerState.client_index(index),
        bound: to_bound_type(item.bound),
        favorite: item.favorite == 1
      })
    )
  end

  @spec item_fields(InventoryItem.t(), %{non_neg_integer() => String.t()}) :: map()
  defp item_fields(%InventoryItem{} = item, names) do
    {creator_kind, creator_id, signer_name} =
      case ItemCraft.from_map(item.craft) do
        {:ok, %ItemCraft{kind: :signed, creator_char_id: id}} ->
          {:CREATOR_SIGNED, id, Map.get(names, id, "")}

        {:ok, %ItemCraft{kind: :forged, creator_char_id: id}} ->
          {:CREATOR_FORGED, id, Map.get(names, id, "")}

        :error ->
          {:CREATOR_NONE, 0, ""}
      end

    %{
      amount: item.amount,
      nameid: item.nameid,
      identified: item.identify == 1,
      attribute: item.attribute,
      refine: item.refine,
      cards: [item.card0, item.card1, item.card2, item.card3],
      location: item.equip,
      type: client_type(item.nameid),
      expire_time: encode_expire_time(item.expire_time),
      look: item_view(item.nameid),
      weight: item_weight(item.nameid),
      signer_name: signer_name,
      creator_id: creator_id,
      creator_kind: creator_kind
    }
  end

  @spec item_weight(integer()) :: non_neg_integer()
  defp item_weight(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{weight: weight}} -> weight
      {:error, :item_not_found} -> 0
    end
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
