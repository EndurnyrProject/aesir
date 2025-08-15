defmodule Aesir.ZoneServer.Packets.CzRequestMove2 do
  @moduledoc """
  CZ_REQUEST_MOVE2 (0x035F) - Modern client movement packet.
  
  This is the modern variant of CZ_REQUEST_MOVE used by recent clients.
  The client sends the destination coordinates encoded in 3 bytes.
  
  Structure:
  - packet_type: 2 bytes (0x035F)
  - dest: 3 bytes (encoded position)
  
  Total size: 5 bytes
  """
  use Aesir.Commons.Network.Packet
  import Bitwise

  @packet_id 0x035F
  @packet_size 5

  defstruct [:dest_x, :dest_y]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, dest_encoded::binary-size(3)>>) do
    {x, y} = decode_position(dest_encoded)
    
    {:ok,
     %__MODULE__{
       dest_x: x,
       dest_y: y
     }}
  end

  def parse(_), do: {:error, :invalid_packet}

  @doc """
  Decodes RO position format (3 bytes) to x,y coordinates.
  Based on RBUFPOS from rAthena.
  
  The encoding packs x,y coordinates into 3 bytes:
  - byte0: x >> 2
  - byte1: (x << 6) | (y >> 4)
  - byte2: (y << 4) | dir (we ignore dir for movement requests)
  """
  def decode_position(<<byte0, byte1, byte2>>) do
    x = (byte0 <<< 2) ||| (byte1 >>> 6)
    y = ((byte1 &&& 0x3F) <<< 4) ||| (byte2 >>> 4)
    
    {x, y}
  end
end