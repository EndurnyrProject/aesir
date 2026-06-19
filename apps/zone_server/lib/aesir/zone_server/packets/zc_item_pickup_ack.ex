defmodule Aesir.ZoneServer.Packets.ZcItemPickupAck do
  @moduledoc """
  ZC_ITEM_PICKUP_ACK packet (0x0A37, `ZC_ITEM_PICKUP_ACK_V7`)

  Sent to the owning client when an item enters the inventory (success) or a
  pickup/add fails. Confirms the addition and lets the client place the item at
  the reported index.

  Latest layout (`PACKET_ZC_ITEM_PICKUP_ACK`, PACKETVER >= 20160921):
  - packet_id: 0x0A37 (2 bytes, little-endian)
  - index: client inventory index, server index + 2 (2 bytes)
  - count: amount added (2 bytes)
  - nameid: item id (4 bytes)
  - identify: identification flag (1 byte)
  - attribute: 0 = normal, 1 = broken (1 byte)
  - refine: refinement level (1 byte)
  - card[4]: inserted card ids (4 bytes each, 16 total)
  - location: equip position bitmask, 0 if held in inventory (4 bytes)
  - type: client `IT_*` enum (1 byte)
  - result: pickup result code (1 byte)
  - hire_expire: unix expiration timestamp, 0 = none (4 bytes)
  - bind_on_equip: bind-on-equip type (2 bytes)
  - option_data[5]: random options, index(2)/value(2)/param(1) each (25 total)
  - favorite: favorite-tab flag (1 byte)
  - look: equip sprite number (2 bytes)

  Unlike the inventory item-list packets, `PACKET_ZC_ITEM_PICKUP_ACK` carries no
  option-count byte. Random options are out of scope for this slice, so the
  option block is zero-filled.
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @packet_id 0x0A37
  @packet_size 69

  @random_options_size 25

  @pickup_success 0
  @pickup_inventory_full 1
  @pickup_overweight 2
  @pickup_failed 3

  @type t :: %__MODULE__{
          packet_id: integer(),
          index: integer(),
          amount: integer(),
          nameid: integer(),
          identify: integer(),
          attribute: integer(),
          refine: integer(),
          card0: integer(),
          card1: integer(),
          card2: integer(),
          card3: integer(),
          location: integer(),
          type: integer(),
          result: integer(),
          expire_time: integer(),
          bind_on_equip: integer(),
          favorite: integer(),
          look: integer()
        }

  defstruct packet_id: @packet_id,
            index: 0,
            amount: 0,
            nameid: 0,
            identify: 1,
            attribute: 0,
            refine: 0,
            card0: 0,
            card1: 0,
            card2: 0,
            card3: 0,
            location: 0,
            type: 0,
            result: @pickup_success,
            expire_time: 0,
            bind_on_equip: 0,
            favorite: 0,
            look: 0

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    data = <<
      packet.index::16-little,
      packet.amount::16-little,
      packet.nameid::32-little,
      packet.identify::8,
      packet.attribute::8,
      packet.refine::8,
      packet.card0::32-little,
      packet.card1::32-little,
      packet.card2::32-little,
      packet.card3::32-little,
      packet.location::32-little,
      packet.type::8,
      packet.result::8,
      packet.expire_time::32-little,
      packet.bind_on_equip::16-little,
      0::size(@random_options_size)-unit(8),
      packet.favorite::8,
      packet.look::16-little
    >>

    build_packet(@packet_id, data)
  end

  @doc """
  Builds a successful pickup acknowledgment from an `InventoryItem` and its
  session index. The client index offset (+2) is applied, and `type`/`look`
  are resolved from the item database.
  """
  @spec success(InventoryItem.t(), non_neg_integer()) :: t()
  def success(%InventoryItem{} = item, server_index) do
    %__MODULE__{
      index: PlayerState.client_index(server_index),
      amount: item.amount,
      nameid: item.nameid,
      identify: item.identify,
      attribute: item.attribute,
      refine: item.refine,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      location: item.equip,
      type: client_type(item.nameid),
      result: @pickup_success,
      expire_time: encode_expire_time(item.expire_time),
      bind_on_equip: item.bound,
      favorite: item.favorite,
      look: item_view(item.nameid)
    }
  end

  @doc """
  Builds a failed pickup acknowledgment carrying the item id and a result code.
  """
  @spec failure(integer(), integer()) :: t()
  def failure(nameid, reason \\ @pickup_failed) do
    %__MODULE__{nameid: nameid, result: reason}
  end

  @doc """
  Builds an inventory-full failure acknowledgment.
  """
  @spec inventory_full(integer()) :: t()
  def inventory_full(nameid), do: failure(nameid, @pickup_inventory_full)

  @doc """
  Builds an overweight failure acknowledgment.
  """
  @spec overweight(integer()) :: t()
  def overweight(nameid), do: failure(nameid, @pickup_overweight)

  @doc "Result code for a successful pickup/add."
  @spec pickup_success() :: non_neg_integer()
  def pickup_success, do: @pickup_success

  @doc "Result code for a rejected add: inventory slots full."
  @spec pickup_inventory_full() :: non_neg_integer()
  def pickup_inventory_full, do: @pickup_inventory_full

  @doc "Result code for a rejected add: over max weight."
  @spec pickup_overweight() :: non_neg_integer()
  def pickup_overweight, do: @pickup_overweight

  @doc "Generic pickup failure result code."
  @spec pickup_failed() :: non_neg_integer()
  def pickup_failed, do: @pickup_failed

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
      {:ok, %{view: view}} -> view
      {:error, :item_not_found} -> 0
    end
  end

  @spec encode_expire_time(NaiveDateTime.t() | nil) :: integer()
  defp encode_expire_time(nil), do: 0

  defp encode_expire_time(datetime) do
    datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end
end
