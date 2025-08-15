defmodule Aesir.ZoneServer.Packets.ZcParChange do
  @moduledoc """
  ZC_PAR_CHANGE packet (0x00B0) - Notifies client of a character parameter change.

  This is the primary packet for updating character status values like HP, SP,
  experience, weight, stats, etc. Used for most numeric status updates.

  Structure:
  - packet_type: 2 bytes (0x00B0)
  - var_id: 2 bytes (status parameter ID from StatusParams)
  - value: 4 bytes (new value for the parameter)

  Total size: 8 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x00B0
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
