defmodule Aesir.CharServer.Packets.ChDeleteChar do
  @moduledoc """
  CH_DELETE_CHAR packet (0x0068) - Client requests character deletion.

  Structure:
  - packet_type: 2 bytes (0x0068)
  - char_id: 4 bytes (character ID)
  - email: 40 bytes (email for verification)

  Total size: 46 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0068
  @packet_size 46

  defstruct [:char_id, :email]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, data::binary>>) do
    parse(data)
  end

  def parse(<<char_id::32-little, email::binary-size(40)>>) do
    {:ok,
     %__MODULE__{
       char_id: char_id,
       email: extract_string(email)
     }}
  end

  def parse(_), do: {:error, :invalid_packet}
end
