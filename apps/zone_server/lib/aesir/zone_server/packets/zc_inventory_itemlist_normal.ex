defmodule Aesir.ZoneServer.Packets.ZcInventoryItemlistNormal do
  @moduledoc """
  ZC_INVENTORY_ITEMLIST_NORMAL packet (0x0B09)

  Sends the player's stackable (non-equipped) inventory items, framed between
  `ZC_INVENTORY_START` (0x0B08) and `ZC_INVENTORY_END` (0x0B0B).

  Variable layout (PACKETVER 2018-09-12+):
  - packet_id: 0x0B09 (2 bytes, little-endian)
  - packet_length: total byte size (2 bytes, little-endian)
  - inv_type: inventory type (1 byte) — 0 = INVTYPE_INVENTORY
  - items: array of `NORMALITEM_INFO` (34 bytes each)

  Each `NORMALITEM_INFO`:
  - index: client inventory index, server index + 2 (2 bytes)
  - nameid: item id (4 bytes)
  - type: client `IT_*` enum (1 byte)
  - amount: item count (2 bytes)
  - wear_state: equip bitmask, 0 for non-equipped (4 bytes)
  - card[4]: inserted card ids (4 bytes each, 16 total)
  - expire_time: unix expiration timestamp, 0 = none (4 bytes)
  - flag: bit0 IsIdentified, bit1 PlaceETCTab (1 byte)

  Random options are out of scope for this slice; the card slot is filled from
  the row's cards and the rest defaults to zero.
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @packet_id 0x0B09
  @packet_size :variable

  @type item_entry :: %{
          index: non_neg_integer(),
          nameid: integer(),
          type: non_neg_integer(),
          amount: integer(),
          wear_state: integer(),
          card0: integer(),
          card1: integer(),
          card2: integer(),
          card3: integer(),
          expire_time: integer(),
          identify: integer()
        }

  @type t :: %__MODULE__{
          inv_type: non_neg_integer(),
          items: [item_entry()]
        }

  defstruct inv_type: 0, items: []

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{inv_type: inv_type, items: items}) do
    items_data = items |> Enum.map(&build_item/1) |> IO.iodata_to_binary()
    build_variable_packet(@packet_id, <<inv_type::8, items_data::binary>>)
  end

  @doc """
  Builds the packet from the indexed inventory map, including only non-equipped
  items. Indices come from the unified session index space (+2 client offset)
  and item type is resolved from the item database.
  """
  @spec from_inventory(%{non_neg_integer() => InventoryItem.t()}) :: t()
  def from_inventory(inventory) when is_map(inventory) do
    items =
      inventory
      |> Enum.filter(fn {_index, item} -> item.equip == 0 end)
      |> Enum.sort_by(fn {index, _item} -> index end)
      |> Enum.map(fn {index, item} -> convert_item(index, item) end)

    %__MODULE__{items: items}
  end

  @spec convert_item(non_neg_integer(), InventoryItem.t()) :: item_entry()
  defp convert_item(index, %InventoryItem{} = item) do
    %{
      index: PlayerState.client_index(index),
      nameid: item.nameid,
      type: client_type(item.nameid),
      amount: item.amount,
      wear_state: item.equip,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      expire_time: encode_expire_time(item.expire_time),
      identify: item.identify
    }
  end

  @spec build_item(item_entry()) :: binary()
  defp build_item(%{
         index: index,
         nameid: nameid,
         type: type,
         amount: amount,
         wear_state: wear_state,
         card0: card0,
         card1: card1,
         card2: card2,
         card3: card3,
         expire_time: expire_time,
         identify: identify
       }) do
    <<
      index::16-little,
      nameid::32-little,
      type::8,
      amount::16-little,
      wear_state::32-little,
      card0::32-little,
      card1::32-little,
      card2::32-little,
      card3::32-little,
      expire_time::32-little,
      identify_flag(identify)::8
    >>
  end

  @spec client_type(integer()) :: non_neg_integer()
  defp client_type(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{type: type}} -> ClientItemType.to_client_type(type)
      {:error, :item_not_found} -> ClientItemType.to_client_type(:etc)
    end
  end

  @spec encode_expire_time(NaiveDateTime.t() | nil) :: integer()
  defp encode_expire_time(nil), do: 0

  defp encode_expire_time(datetime) do
    datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end

  @spec identify_flag(integer()) :: non_neg_integer()
  defp identify_flag(1), do: 1
  defp identify_flag(_), do: 0
end
