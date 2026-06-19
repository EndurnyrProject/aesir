defmodule Aesir.ZoneServer.Packets.ZcInventoryStart do
  @moduledoc """
  ZC_INVENTORY_START packet (0x0B08)

  Opens an inventory-list transmission. Sent before the normal/equip item lists
  during the initial sync (and reused for storage/cart on later slices), closed
  by `ZC_INVENTORY_END` (0x0B0B).

  Modern variable-length layout (PACKETVER 2018-09-19+):
  - packet_id: 0x0B08 (2 bytes, little-endian)
  - packet_length: total byte size (2 bytes, little-endian)
  - inv_type: inventory type (1 byte) — 0 = INVTYPE_INVENTORY
  - name: NUL-terminated, capped at 24 bytes
  """

  use Aesir.Commons.Network.Packet

  @packet_id 0x0B08
  @packet_size :variable
  @max_name_length 24

  @typedoc "Inventory transmission type (INVTYPE_*); 0 is the player inventory."
  @type inv_type :: non_neg_integer()

  @type t :: %__MODULE__{
          inv_type: inv_type(),
          name: String.t()
        }

  defstruct inv_type: 0, name: ""

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{inv_type: inv_type, name: name}) do
    build_variable_packet(@packet_id, <<inv_type::8, encode_name(name)::binary>>)
  end

  @spec encode_name(String.t()) :: binary()
  defp encode_name(name) do
    truncated = binary_part(name, 0, min(byte_size(name), @max_name_length - 1))
    <<truncated::binary, 0>>
  end
end
