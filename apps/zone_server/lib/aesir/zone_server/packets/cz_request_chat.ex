defmodule Aesir.ZoneServer.Packets.CzRequestChat do
  @moduledoc """
  Client to Server: Request to send a normal chat message.
  Packet ID: 0x008c
  """

  use Aesir.Commons.Network.Packet
  use TypedStruct

  @packet_id 0x008C
  @packet_size :variable
  @packet_size_header 4

  typedstruct do
    @typedoc "Client chat message request"
    field :message, String.t()
  end

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(
        <<@packet_id::16-little, packet_length::16-little,
          message_data::binary-size(packet_length - @packet_size_header)>>
      ) do
    message = message_data |> to_string() |> String.trim_trailing("\0")
    {:ok, %__MODULE__{message: message}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{} = _packet) do
    raise "CzRequestChat is a client-to-server packet and should not be built by the server."
  end
end
