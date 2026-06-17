defmodule Aesir.ZoneServer.Packets.ZcBlownback do
  @moduledoc """
  ZC_BLOWNBACK (0x01B1) - Snaps a unit to a destination cell and plays the
  knockback visual.

  Sent to nearby players when a unit is blown back (e.g. Magnum Break), telling
  the client to slide the unit to `{dst_x, dst_y}`.

  Fixed-size, 10 bytes:
  - header (2) + unit GID (4) + dst_x (2) + dst_y (2)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x01B1
  @packet_size 10

  @typedoc "Knockback destination packet."
  @type t :: %__MODULE__{
          unit_id: non_neg_integer(),
          dst_x: non_neg_integer(),
          dst_y: non_neg_integer()
        }

  defstruct [:unit_id, :dst_x, :dst_y]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, unit_id::32-little, dst_x::16-little, dst_y::16-little>>) do
    {:ok, %__MODULE__{unit_id: unit_id, dst_x: dst_x, dst_y: dst_y}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{unit_id: unit_id, dst_x: dst_x, dst_y: dst_y}) do
    build_packet(@packet_id, <<unit_id::32-little, dst_x::16-little, dst_y::16-little>>)
  end
end
