defmodule Aesir.ZoneServer.Packets.ZcNormalItemlist do
  @moduledoc """
  ZC_NORMAL_ITEMLIST packet (0x00A3)

  Sends the player's regular inventory items (non-equipment) to the client.
  This packet is sent during login sequence after LoadEndAck.

  Packet Structure:
  - packet_id: 0x00A3
  - packet_length: variable
  - items: array of inventory items

  Each item contains:
  - index: inventory slot (0-based)
  - nameid: item ID
  - amount: item count
  - type: item type (0=usable, 2=usable, 3=etc, 6=pet egg, 7=weapon, 8=armor, etc.)
  - identify: identification flag (0=unidentified, 1=identified)
  - attribute: item attribute (0=normal, 1=broken)
  - refine: refinement level
  - card[4]: inserted cards
  - expire_time: expiration timestamp (0 = no expiration)
  - favorite: favorite flag
  - bound: bound type
  - option[5]: random options (id, value, param)
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Models.InventoryItem

  @packet_id 0x00A3
  @packet_size :variable
  # Size of each item entry in bytes
  @item_size 28

  @type inventory_item :: %{
          index: integer(),
          nameid: integer(),
          amount: integer(),
          type: integer(),
          identify: integer(),
          attribute: integer(),
          refine: integer(),
          card0: integer(),
          card1: integer(),
          card2: integer(),
          card3: integer(),
          expire_time: integer(),
          favorite: integer(),
          bound: integer(),
          random_options: list()
        }

  @type t :: %__MODULE__{
          packet_id: integer(),
          packet_length: integer(),
          items: [inventory_item()]
        }

  defstruct packet_id: @packet_id,
            packet_length: 0,
            items: []

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, packet_length::16-little, data::binary>>) do
    parse_items(data, packet_length - 4, [])
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{items: items}) do
    items_data = Enum.map(items, &build_item/1) |> IO.iodata_to_binary()
    packet_length = 4 + byte_size(items_data)

    packet_data = <<packet_length::16-little, items_data::binary>>
    build_packet(@packet_id, packet_data)
  end

  @doc """
  Creates a ZC_NORMAL_ITEMLIST packet from a list of InventoryItem structs.
  Filters out equipped items as they are sent via ZC_EQUIPITEM_LIST.
  """
  @spec from_inventory_items([InventoryItem.t()]) :: __MODULE__.t()
  def from_inventory_items(inventory_items) do
    items =
      inventory_items
      # Only non-equipped items
      |> Enum.filter(fn item -> item.equip == 0 end)
      |> Enum.with_index()
      |> Enum.map(fn {item, index} -> convert_inventory_item(item, index) end)

    %__MODULE__{
      packet_length: 4 + length(items) * @item_size,
      items: items
    }
  end

  # Private functions

  defp parse_items(<<>>, 0, acc), do: {:ok, %__MODULE__{items: Enum.reverse(acc)}}
  defp parse_items(<<>>, _remaining, _acc), do: {:error, :invalid_packet_length}

  defp parse_items(
         <<
           index::16-little,
           nameid::16-little,
           amount::16-little,
           type::8,
           identify::8,
           attribute::8,
           refine::8,
           card0::16-little,
           card1::16-little,
           card2::16-little,
           card3::16-little,
           expire_time::32-little,
           favorite::8,
           bound::8,
           # Random options - simplified for now
           _random_options::binary-size(10),
           rest::binary
         >>,
         remaining,
         acc
       )
       when remaining >= @item_size do
    item = %{
      index: index,
      nameid: nameid,
      amount: amount,
      type: type,
      identify: identify,
      attribute: attribute,
      refine: refine,
      card0: card0,
      card1: card1,
      card2: card2,
      card3: card3,
      expire_time: expire_time,
      favorite: favorite,
      bound: bound,
      # TODO: Parse random options properly
      random_options: []
    }

    parse_items(rest, remaining - @item_size, [item | acc])
  end

  defp parse_items(_, _, _), do: {:error, :invalid_item_data}

  defp build_item(%{
         index: index,
         nameid: nameid,
         amount: amount,
         type: type,
         identify: identify,
         attribute: attribute,
         refine: refine,
         card0: card0,
         card1: card1,
         card2: card2,
         card3: card3,
         expire_time: expire_time,
         favorite: favorite,
         bound: bound
       }) do
    # Random options - simplified as zeros for now
    # 10 bytes of zeros
    random_options_data = <<0::80>>

    <<
      index::16-little,
      nameid::16-little,
      amount::16-little,
      type::8,
      identify::8,
      attribute::8,
      refine::8,
      card0::16-little,
      card1::16-little,
      card2::16-little,
      card3::16-little,
      expire_time::32-little,
      favorite::8,
      bound::8,
      random_options_data::binary
    >>
  end

  defp convert_inventory_item(%InventoryItem{} = item, index) do
    expire_time =
      case item.expire_time do
        nil -> 0
        datetime -> DateTime.from_naive!(datetime, "Etc/UTC") |> DateTime.to_unix()
      end

    %{
      index: index,
      nameid: item.nameid,
      amount: item.amount,
      # TODO: Get from item database
      type: determine_item_type(item.nameid),
      identify: item.identify,
      attribute: item.attribute,
      refine: item.refine,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      expire_time: expire_time,
      favorite: item.favorite,
      bound: item.bound,
      # TODO: Convert random_options map to list
      random_options: []
    }
  end

  # TODO: Implement proper item type lookup from item database
  # For now, return 3 (etc) for all items
  defp determine_item_type(_nameid), do: 3
end
