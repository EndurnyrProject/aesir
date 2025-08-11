defmodule Aesir.CharServer.Packets.ChReqCharDelete2 do
  @moduledoc """
  CH_REQ_CHAR_DELETE2 packet (0x0827) - Request character deletion with timer.

  Modern character deletion system that adds a delay before actual deletion.

  Structure (6 bytes):
  - packet_id: 2 bytes (0x0827)
  - char_id: 4 bytes (character ID to delete)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0827
  @packet_size 6

  defstruct [:char_id]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, char_id::32-little>>) do
    {:ok, %__MODULE__{char_id: char_id}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{char_id: char_id}) do
    <<@packet_id::16-little, char_id::32-little>>
  end
end
