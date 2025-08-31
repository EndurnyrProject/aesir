defmodule Aesir.ZoneServer.Packets.ZcItemPickupAck do
  @moduledoc """
  ZC_ITEM_PICKUP_ACK packet (0x00A0)

  Sent to the client when an item is picked up (success) or pickup fails.
  This packet confirms item pickup and updates the client's inventory.

  Packet Structure:
  - packet_id: 0x00A0
  - index: inventory slot where item was placed (0-based)
  - amount: amount of items picked up
  - nameid: item ID that was picked up
  - identify: identification flag
  - attribute: item attribute (0=normal, 1=broken) 
  - refine: refinement level
  - card[4]: inserted cards
  - location: equipment position if auto-equipped (0 if in inventory)
  - type: item type
  - result: pickup result (0=success, 1=inventory full, 2=overweight, etc.)
  - expire_time: expiration timestamp
  - bound: bound type
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Models.InventoryItem

  @packet_id 0x00A0
  @packet_size 23

  # Pickup result codes
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
          bound: integer()
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
            bound: 0

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, data::binary-size(21)>>) do
    parse_data(data)
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{} = packet) do
    data = <<
      packet.index::16-little,
      packet.amount::16-little,
      packet.nameid::16-little,
      packet.identify::8,
      packet.attribute::8,
      packet.refine::8,
      packet.card0::16-little,
      packet.card1::16-little,
      packet.card2::16-little,
      packet.card3::16-little,
      packet.location::16-little,
      packet.type::8,
      packet.result::8,
      packet.expire_time::32-little,
      packet.bound::8
    >>

    build_packet(@packet_id, data)
  end

  @doc """
  Creates a successful pickup acknowledgment from an InventoryItem.
  """
  @spec success(InventoryItem.t(), integer()) :: __MODULE__.t()
  def success(%InventoryItem{} = item, inventory_index) do
    expire_time =
      case item.expire_time do
        nil -> 0
        datetime -> DateTime.from_naive!(datetime, "Etc/UTC") |> DateTime.to_unix()
      end

    %__MODULE__{
      index: inventory_index,
      amount: item.amount,
      nameid: item.nameid,
      identify: item.identify,
      attribute: item.attribute,
      refine: item.refine,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      # 0 for inventory, > 0 if auto-equipped
      location: item.equip,
      type: determine_item_type(item.nameid),
      result: @pickup_success,
      expire_time: expire_time,
      bound: item.bound
    }
  end

  @doc """
  Creates a failed pickup acknowledgment.
  """
  @spec failure(integer(), integer()) :: __MODULE__.t()
  def failure(nameid, reason \\ @pickup_failed) do
    %__MODULE__{
      index: 0,
      amount: 0,
      nameid: nameid,
      identify: 1,
      attribute: 0,
      refine: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0,
      location: 0,
      type: 0,
      result: reason,
      expire_time: 0,
      bound: 0
    }
  end

  @doc """
  Creates an inventory full failure.
  """
  @spec inventory_full(integer()) :: __MODULE__.t()
  def inventory_full(nameid) do
    failure(nameid, @pickup_inventory_full)
  end

  @doc """
  Creates an overweight failure.
  """
  @spec overweight(integer()) :: __MODULE__.t()
  def overweight(nameid) do
    failure(nameid, @pickup_overweight)
  end

  # Pickup result constants for external use
  def pickup_success, do: @pickup_success
  def pickup_inventory_full, do: @pickup_inventory_full
  def pickup_overweight, do: @pickup_overweight
  def pickup_failed, do: @pickup_failed

  # Private functions

  defp parse_data(<<
         index::16-little,
         amount::16-little,
         nameid::16-little,
         identify::8,
         attribute::8,
         refine::8,
         card0::16-little,
         card1::16-little,
         card2::16-little,
         card3::16-little,
         location::16-little,
         type::8,
         result::8,
         expire_time::32-little,
         bound::8
       >>) do
    {:ok,
     %__MODULE__{
       index: index,
       amount: amount,
       nameid: nameid,
       identify: identify,
       attribute: attribute,
       refine: refine,
       card0: card0,
       card1: card1,
       card2: card2,
       card3: card3,
       location: location,
       type: type,
       result: result,
       expire_time: expire_time,
       bound: bound
     }}
  end

  defp parse_data(_), do: {:error, :invalid_packet_data}

  # TODO: Implement proper item type lookup from item database
  # For now, return 3 (etc) for all items
  defp determine_item_type(_nameid), do: 3
end
