defmodule Aesir.ZoneServer.Packets.ZcStatusChange do
  @moduledoc """
  ZC_STATUS_CHANGE_ACK (0x00BC) - Result of a stat-raise request.

  Structure:
  - packet_type: 2 bytes (0x00BC)
  - sp: 2 bytes (StatusParams id that was changed)
  - ok: 1 byte (0 = failure, 1 = success)
  - value: 1 byte (new stat value, capped to 255)

  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x00BC
  @packet_size 6

  @type t :: %__MODULE__{sp: non_neg_integer(), ok: non_neg_integer(), value: non_neg_integer()}

  defstruct [:sp, :ok, :value]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{sp: sp, ok: ok, value: value}) do
    <<@packet_id::16-little, sp::16-little, ok::8, value::8>>
  end
end
