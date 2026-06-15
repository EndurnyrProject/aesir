defmodule Aesir.ZoneServer.Packets.ZcResurrection do
  @moduledoc """
  ZC_RESURRECTION (0x0148) - Makes a unit stand back up after death.

  Sent to nearby clients (and the resurrected unit) so the sprite stands up
  in place. Used by rAthena as the fallback when warping a respawning player
  fails, and for in-place revivals.

  Structure:
  - packet_type: 2 bytes (0x0148)
  - gid: 4 bytes (unit ID - account_id for players)
  - type: 2 bytes (ignored by the client)

  Total size: 8 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0148
  @packet_size 8

  @type t :: %__MODULE__{gid: non_neg_integer(), type: non_neg_integer()}

  defstruct [:gid, type: 0]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    <<
      @packet_id::16-little,
      packet.gid::32-little,
      packet.type::16-little
    >>
  end
end
