defmodule Aesir.ZoneServer.Packets.ZcNotifyChat do
  @moduledoc """
  Server to Client: Notifies clients of a chat message in the area.
  Packet ID: 0x008d
  """

  use Aesir.Commons.Network.Packet
  use TypedStruct

  @packet_id 0x008D
  @packet_size :variable
  @packet_size_header 4

  typedstruct do
    @typedoc "Chat message broadcast to clients"
    field :gid, non_neg_integer()
    field :message, String.t()
  end

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(
        <<@packet_id::16-little, packet_length::16-little, gid::32-little,
          message_data::binary-size(packet_length - @packet_size_header - 4)>>
      ) do
    message = message_data |> to_string() |> String.trim_trailing("\0")
    {:ok, %__MODULE__{gid: gid, message: message}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{gid: gid, message: message}) do
    message_with_null = message <> <<0>>
    message_length = byte_size(message_with_null)
    packet_length = @packet_size_header + 4 + message_length

    <<@packet_id::16-little, packet_length::16-little, gid::32-little, message_with_null::binary>>
  end
end
