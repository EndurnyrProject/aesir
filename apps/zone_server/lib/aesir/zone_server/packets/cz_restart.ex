defmodule Aesir.ZoneServer.Packets.CzRestart do
  @moduledoc """
  CZ_RESTART (0x00B2) - Response to the death/system menu.

  Sent when a dead player picks an option from the death dialog, or when a
  player requests to return to character select.

  Structure:
  - packet_type: 2 bytes (0x00B2)
  - type: 1 byte

  Types:
  - 0: Restart (respawn at save point)
  - 1: Char-select (return to character selection / disconnect)

  Total size: 3 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x00B2
  @packet_size 3

  @type t :: %__MODULE__{type: non_neg_integer()}

  defstruct [:type]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, type::8>>) do
    {:ok, %__MODULE__{type: type}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
