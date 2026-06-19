defmodule Aesir.ZoneServer.Packets.CzReqWearEquip do
  @moduledoc """
  CZ_REQ_WEAR_EQUIP (0x0998) - Equip item request packet.

  Sent by the client when the player attempts to equip an item from their inventory.

  Structure (PACKETVER >= 20120925):
  - packet_type: 2 bytes (0x0998)
  - index: 2 bytes (uint16) — client-side inventory index (server index + 2; subtract 2 in handler)
  - position: 4 bytes (uint32) — EQP bitmask of the target equipment slot(s)

  Total size: 8 bytes

  Note: `index` carries the client offset (+2). The handler (Task 10) is responsible for
  subtracting 2 to obtain the server-side session index before resolving the item.
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0998
  @packet_size 8

  defstruct [:index, :position]

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          position: non_neg_integer()
        }

  @impl true
  @spec packet_id() :: non_neg_integer()
  def packet_id, do: @packet_id

  @impl true
  @spec packet_size() :: pos_integer()
  def packet_size, do: @packet_size

  @impl true
  @spec parse(binary()) :: {:ok, t()} | {:error, :invalid_packet}
  def parse(<<@packet_id::16-little, index::16-little, position::32-little>>) do
    {:ok, %__MODULE__{index: index, position: position}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
