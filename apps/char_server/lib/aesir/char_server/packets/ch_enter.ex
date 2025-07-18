defmodule Aesir.CharServer.Packets.ChEnter do
  @moduledoc """
  CH_ENTER packet (0x0065) - Client requests character list from char server.

  Structure:
  - packet_type: 2 bytes (0x0065)
  - aid: 4 bytes (account ID)
  - login_id1: 4 bytes
  - login_id2: 4 bytes
  - unknown: 2 bytes
  - sex: 1 byte

  Total size: 17 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0065
  @packet_size 17

  defstruct [:aid, :login_id1, :login_id2, :unknown, :sex]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, data::binary>>) do
    parse(data)
  end

  def parse(
        <<aid::32-little, login_id1::32-little, login_id2::32-little, unknown::16-little, sex::8>>
      ) do
    {:ok,
     %__MODULE__{
       aid: aid,
       login_id1: login_id1,
       login_id2: login_id2,
       unknown: unknown,
       sex: sex
     }}
  end

  def parse(_), do: {:error, :invalid_packet}
end
