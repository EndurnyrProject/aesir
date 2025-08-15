defmodule Aesir.ZoneServer.Packets.ZcLongparChange do
  @moduledoc """
  ZC_LONGPAR_CHANGE packet (0x00B1) - Notifies client of a character parameter change (long value).

  Similar to ZC_PAR_CHANGE but used for larger values that require more than 32 bits,
  such as large experience values or zeny amounts.

  Structure:
  - packet_type: 2 bytes (0x00B1)
  - var_id: 2 bytes (status parameter ID from StatusParams)
  - value: 4 bytes (new value for the parameter)

  Total size: 8 bytes

  Note: Despite the name "long", this packet still uses 32-bit values in the current
  packet version. The distinction is primarily for semantic clarity and future compatibility.
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x00B1
  @packet_size 8

  defstruct [:var_id, :value]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{var_id: var_id, value: value}) do
    <<@packet_id::16-little, var_id::16-little, value::32-little>>
  end
end
