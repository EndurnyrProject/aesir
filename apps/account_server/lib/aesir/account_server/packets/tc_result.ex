defmodule Aesir.AccountServer.Packets.TcResult do
  use Aesir.Network.Packet

  @packet_id 0x0AE3
  @packet_size 34

  defstruct type: 0,
            unknown1: "S1000",
            unknown2: "token"

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = p) do
    unknown1_padded = String.pad_trailing(p.unknown1, 20, "\0")
    unknown2_padded = String.pad_trailing(p.unknown2, 6, "\0")

    <<@packet_id::little-16, @packet_size::little-16, p.type::little-32,
      unknown1_padded::binary-size(20), unknown2_padded::binary-size(6)>>
  end
end
