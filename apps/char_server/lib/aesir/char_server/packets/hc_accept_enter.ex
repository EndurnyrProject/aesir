defmodule Aesir.CharServer.Packets.HcAcceptEnter do
  @moduledoc """
  HC_ACCEPT_ENTER packet (0x006b) - Character list response.

  Structure:
  - packet_type: 2 bytes (0x006b)
  - length: 2 bytes (total packet length)
  - header_extension: 23 bytes (slot counts + 20 reserved bytes)
  - characters: variable (175 bytes per character)

  Each character entry is the 175-byte `CHARACTER_INFO` block encoded by
  `Aesir.CharServer.Packets.CharacterInfo`, which is the single source of truth
  for that layout (see that module for the field table).
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.CharServer.Packets.CharacterInfo

  @packet_id 0x006B
  @packet_size :variable

  defstruct [:characters]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, _length::16-little, _data::binary>>) do
    {:ok, %__MODULE__{characters: []}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{characters: characters}) do
    max_chars = 15
    min_chars = 9
    premium_chars = 9

    header_extension = <<
      # Max slots
      max_chars::8,
      # Available slots (PremiumStartSlot)
      min_chars::8,
      # Premium slots
      premium_chars::8,
      # 20 unknown bytes
      0::size(20 * 8)
    >>

    if Enum.empty?(characters) do
      packet_data = header_extension
      build_variable_packet(@packet_id, packet_data)
    else
      char_data =
        characters
        |> Enum.map(&CharacterInfo.serialize/1)
        |> IO.iodata_to_binary()

      packet_data = <<header_extension::binary, char_data::binary>>
      build_variable_packet(@packet_id, packet_data)
    end
  end
end
