defmodule Aesir.ZoneServer.Packets.CzStatusChange do
  @moduledoc """
  CZ_STATUS_CHANGE (0x00BB) - Client requests to raise a primary stat.

  Structure:
  - packet_type: 2 bytes (0x00BB)
  - status_id: 2 bytes (StatusParams id; SP_STR..SP_LUK = 13..18)
  - amount: 1 byte (points to raise, normally 1)

  Total size: 5 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x00BB
  @packet_size 5

  @type t :: %__MODULE__{status_id: non_neg_integer(), amount: non_neg_integer()}

  defstruct [:status_id, :amount]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, status_id::16-little, amount::8>>) do
    {:ok, %__MODULE__{status_id: status_id, amount: amount}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
