defmodule Aesir.ZoneServer.Packets.ZcInventoryEnd do
  @moduledoc """
  ZC_INVENTORY_END packet (0x0B0B)

  Closes an inventory-list transmission opened by `ZC_INVENTORY_START` (0x0B08),
  sent after the normal/equip item lists during the initial sync.

  Fixed layout (PACKETVER 2018-09-12+):
  - packet_id: 0x0B0B (2 bytes, little-endian)
  - inv_type: inventory type (1 byte) — 0 = INVTYPE_INVENTORY
  - flag: completion flag (1 byte) — 0 = success
  """

  use Aesir.Commons.Network.Packet

  @packet_id 0x0B0B
  @packet_size 4

  @typedoc "Inventory transmission type (INVTYPE_*); 0 is the player inventory."
  @type inv_type :: non_neg_integer()

  @type t :: %__MODULE__{
          inv_type: inv_type(),
          flag: non_neg_integer()
        }

  defstruct inv_type: 0, flag: 0

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{inv_type: inv_type, flag: flag}) do
    build_packet(@packet_id, <<inv_type::8, flag::8>>)
  end
end
