defmodule Aesir.AccountServer.Packets.AcRefuseLogin do
  @moduledoc """
  AC_REFUSE_LOGIN packet (0x006A) - Login failure response.

  Fixed-size packet structure:
  - packet_type: 2 bytes (0x006A)
  - reason_code: 1 byte
  - block_date: 20 bytes (string representation)

  Total size: 23 bytes

  Common reason codes:
  - 0: Unregistered ID
  - 1: Incorrect Password
  - 2: Account expired
  - 3: Rejected from server
  - 4: Blocked by GM
  - 5: Not latest game version
  - 6: Banned
  - 7: Server is full
  - 8: No more accounts from this IP
  - 9: Banned for bot usage
  - 10: Your account is restricted
  - 11: Account in deletion process
  - 99: Account gone
  - 100: Login info remains
  - 101: Investigate password
  """
  use Aesir.Network.Packet

  @packet_id 0x006A
  @packet_size 23

  defstruct [:reason_code, :block_date]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    block_date = pack_string(packet.block_date || "", 20)

    data = <<
      packet.reason_code::8,
      block_date::binary-size(20)
    >>

    build_packet(@packet_id, data)
  end
end
