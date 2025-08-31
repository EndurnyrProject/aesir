defmodule Aesir.ZoneServer.Packets.ZcEquipitemList do
  @moduledoc """
  ZC_EQUIPITEM_LIST packet (0x00A4)

  Sends the player's equipped items to the client.
  This packet is sent during login sequence after the normal itemlist.

  Packet Structure:
  - packet_id: 0x00A4
  - packet_length: variable
  - items: array of equipped items

  Each equipped item contains:
  - index: inventory slot (0-based)
  - nameid: item ID  
  - type: item type (4=weapon, 5=armor, etc.)
  - identify: identification flag (0=unidentified, 1=identified)
  - location: equipment position (bitmask)
  - wlv: weapon level (for weapons)
  - attribute: item attribute (0=normal, 1=broken)
  - refine: refinement level
  - card[4]: inserted cards
  - expire_time: expiration timestamp (0 = no expiration)
  - favorite: favorite flag  
  - bound: bound type
  - option[5]: random options (id, value, param)
  - location2: equipment switch position (for dual equip)
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Models.InventoryItem

  @packet_id 0x00A4
  @packet_size :variable
  # Size of each equipped item entry in bytes
  @item_size 32

  @type equipped_item :: %{
          index: integer(),
          nameid: integer(),
          type: integer(),
          identify: integer(),
          location: integer(),
          wlv: integer(),
          attribute: integer(),
          refine: integer(),
          card0: integer(),
          card1: integer(),
          card2: integer(),
          card3: integer(),
          expire_time: integer(),
          favorite: integer(),
          bound: integer(),
          random_options: list(),
          location2: integer()
        }

  @type t :: %__MODULE__{
          packet_id: integer(),
          packet_length: integer(),
          items: [equipped_item()]
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
  Creates a ZC_EQUIPITEM_LIST packet from a list of InventoryItem structs.
  Filters to only include equipped items (equip > 0).
  """
  @spec from_inventory_items([InventoryItem.t()]) :: __MODULE__.t()
  def from_inventory_items(inventory_items) do
    items =
      inventory_items
      # Only equipped items
      |> Enum.filter(fn item -> item.equip > 0 end)
      |> Enum.with_index()
      |> Enum.map(fn {item, index} -> convert_equipped_item(item, index) end)

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
           type::8,
           identify::8,
           location::16-little,
           wlv::8,
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
           location2::16-little,
           rest::binary
         >>,
         remaining,
         acc
       )
       when remaining >= @item_size do
    item = %{
      index: index,
      nameid: nameid,
      type: type,
      identify: identify,
      location: location,
      wlv: wlv,
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
      random_options: [],
      location2: location2
    }

    parse_items(rest, remaining - @item_size, [item | acc])
  end

  defp parse_items(_, _, _), do: {:error, :invalid_item_data}

  defp build_item(%{
         index: index,
         nameid: nameid,
         type: type,
         identify: identify,
         location: location,
         wlv: wlv,
         attribute: attribute,
         refine: refine,
         card0: card0,
         card1: card1,
         card2: card2,
         card3: card3,
         expire_time: expire_time,
         favorite: favorite,
         bound: bound,
         location2: location2
       }) do
    # Random options - simplified as zeros for now
    # 10 bytes of zeros
    random_options_data = <<0::80>>

    <<
      index::16-little,
      nameid::16-little,
      type::8,
      identify::8,
      location::16-little,
      wlv::8,
      attribute::8,
      refine::8,
      card0::16-little,
      card1::16-little,
      card2::16-little,
      card3::16-little,
      expire_time::32-little,
      favorite::8,
      bound::8,
      random_options_data::binary,
      location2::16-little
    >>
  end

  defp convert_equipped_item(%InventoryItem{} = item, index) do
    expire_time =
      case item.expire_time do
        nil -> 0
        datetime -> DateTime.from_naive!(datetime, "Etc/UTC") |> DateTime.to_unix()
      end

    %{
      index: index,
      nameid: item.nameid,
      # TODO: Get from item database
      type: determine_item_type(item.nameid),
      identify: item.identify,
      # Equipment position bitmask
      location: item.equip,
      # TODO: Get from item database
      wlv: determine_weapon_level(item.nameid),
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
      random_options: [],
      # Equipment switch position
      location2: item.equip_switch
    }
  end

  # TODO: Implement proper item type lookup from item database
  # For now, return 3 (etc) for all items
  defp determine_item_type(_nameid), do: 3

  # TODO: Implement proper weapon level lookup from item database
  # For now, return 0 (no weapon level) for all items
  defp determine_weapon_level(_nameid), do: 0
end
