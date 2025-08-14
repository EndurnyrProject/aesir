defmodule Aesir.ZoneServer.Packets.CzEnter2 do
  @moduledoc """
  CZ_ENTER2 packet (0x0436) - Client requests to enter the map/zone server (newer clients).

  This is the same as CZ_ENTER (0x0072) but used by newer clients.
  This packet is sent by the client after receiving HC_NOTIFY_ZONESVR from char server.

  Structure:
  - packet_type: 2 bytes (0x0436)
  - account_id: 4 bytes
  - char_id: 4 bytes  
  - auth_code: 4 bytes (login_id1)
  - client_time: 4 bytes
  - sex: 1 byte

  Total size: 19 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0436
  @packet_size 19

  defstruct [:account_id, :char_id, :auth_code, :client_time, :sex]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, data::binary>>) do
    parse(data)
  end

  def parse(
        <<account_id::32-little, char_id::32-little, auth_code::32-little, client_time::32-little,
          sex::8>>
      ) do
    {:ok,
     %__MODULE__{
       account_id: account_id,
       char_id: char_id,
       auth_code: auth_code,
       client_time: client_time,
       sex: sex
     }}
  end

  def parse(_), do: {:error, :invalid_packet}
end
