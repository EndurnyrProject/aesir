defmodule Aesir.AccountServer.Packets.CtAuth do
  use Aesir.Commons.Network.Packet

  @packet_id 0x0ACF
  @packet_size 68

  defstruct unknown: <<>>

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, _::binary-size(66)>> = data) do
    {:ok, %__MODULE__{unknown: data}}
  end

  def parse(_), do: {:error, :invalid_packet_size}
end
