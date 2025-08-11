defmodule Aesir.CharServer.Packets.HcCharlistNotify do
  @moduledoc """
  HC_CHARLIST_NOTIFY packet (0x09a0) - Character list notification.

  Structure (6 or 10 bytes depending on version):
  - packet_id: 2 bytes (0x09a0)
  - total_count: 4 bytes (pages to load, typically char_slots/3 or 1)
  - [optional] char_slots: 4 bytes (for some packet versions)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x09A0

  defstruct [:total_count, :char_slots]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: 6

  @impl true
  def parse(<<@packet_id::16-little, total_count::32-little>>) do
    {:ok, %__MODULE__{total_count: total_count}}
  end

  def parse(<<@packet_id::16-little, total_count::32-little, char_slots::32-little>>) do
    {:ok, %__MODULE__{total_count: total_count, char_slots: char_slots}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{} = packet) do
    char_slots = packet.char_slots || 9
    total_count = if char_slots > 3, do: div(char_slots, 3), else: 1

    <<
      @packet_id::16-little,
      total_count::32-little
    >>
  end
end
