defmodule Aesir.ZoneServer.Packets.ZcNotifyCastCancel do
  @moduledoc """
  ZC_DISPEL (0x01B9) - notifies clients that a unit cancelled/interrupted casting.

  Server counterpart to rAthena `clif_skillcastcancel`. Sent to clients in range
  when a cast is interrupted (by damage or movement) so the client removes the
  cast bar.

  Structure (6 bytes):
  - packet_id: 2 bytes (0x01B9)
  - gid: 4 bytes (casting unit GID)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x01B9
  @packet_size 6

  @type t :: %__MODULE__{
          gid: non_neg_integer()
        }

  defstruct [:gid]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{gid: gid}) do
    build_packet(@packet_id, <<gid::32-little>>)
  end
end
