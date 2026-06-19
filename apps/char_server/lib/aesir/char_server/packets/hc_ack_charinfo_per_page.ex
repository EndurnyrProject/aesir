defmodule Aesir.CharServer.Packets.HcAckCharinfoPerPage do
  @moduledoc """
  HC_ACK_CHARINFO_PER_PAGE packet (0x0B72) - Character list response for refresh.

  This is sent in response to CH_CHARLIST_REQ (0x09A1). It carries the same
  character data as HC_ACCEPT_ENTER but without the header extension.

  Structure:
  - packet_id: 2 bytes (0x0B72)
  - packet_length: 2 bytes
  - character_data: variable (175 bytes per character)

  Each character entry is the 175-byte `CHARACTER_INFO` block encoded by
  `Aesir.CharServer.Packets.CharacterInfo`. As a server->client packet it has no
  decode path.
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.CharServer.Packets.CharacterInfo

  @packet_id 0x0B72
  @packet_size -1

  defstruct [:characters]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{characters: characters}) do
    char_data =
      characters
      |> Enum.map(&CharacterInfo.serialize/1)
      |> IO.iodata_to_binary()

    length = 4 + byte_size(char_data)

    main_packet = <<@packet_id::16-little, length::16-little, char_data::binary>>

    # Special handling: if exactly 3 characters, send an additional empty packet
    # This is a Gravity quirk that triggers client finalization
    if length(characters) == 3 do
      empty_packet = <<@packet_id::16-little, 4::16-little>>
      main_packet <> empty_packet
    else
      main_packet
    end
  end
end
