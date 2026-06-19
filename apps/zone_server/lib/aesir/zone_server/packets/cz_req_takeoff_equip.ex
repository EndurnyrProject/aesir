defmodule Aesir.ZoneServer.Packets.CzReqTakeoffEquip do
  @moduledoc """
  CZ_REQ_TAKEOFF_EQUIP (0x00AB) - Unequip item request packet.

  Sent by the client when the player attempts to take off an equipped item.

  Structure:
  - packet_type: 2 bytes (0x00AB)
  - index: 2 bytes (uint16) — client-side inventory index (server index + 2; subtract 2 in handler)

  Total size: 4 bytes

  Note: `index` carries the client offset (+2). The handler (Task 10) is responsible for
  subtracting 2 to obtain the server-side session index before resolving the item.
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x00AB
  @packet_size 4

  defstruct [:index]

  @type t :: %__MODULE__{
          index: non_neg_integer()
        }

  @impl true
  @spec packet_id() :: non_neg_integer()
  def packet_id, do: @packet_id

  @impl true
  @spec packet_size() :: pos_integer()
  def packet_size, do: @packet_size

  @impl true
  @spec parse(binary()) :: {:ok, t()} | {:error, :invalid_packet}
  def parse(<<@packet_id::16-little, index::16-little>>) do
    {:ok, %__MODULE__{index: index}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
