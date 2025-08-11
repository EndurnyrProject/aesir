defmodule Aesir.CharServer.Packets.AccountIdAck do
  @moduledoc """
  Special 4-byte acknowledgment packet sent immediately after receiving CH_ENTER (0x0065).
  This is not a standard packet with header - it's just 4 bytes containing the account ID.
  """
  use Aesir.Commons.Network.Packet

  defstruct [:account_id]

  @impl true
  def packet_id, do: nil

  @impl true
  def packet_size, do: 4

  @impl true
  def parse(<<account_id::32-little>>) do
    {:ok, %__MODULE__{account_id: account_id}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{account_id: account_id}) do
    <<account_id::32-little>>
  end
end
