defmodule Aesir.CharServer.Packets.ChMakeCharV2 do
  @moduledoc """
  CH_MAKE_CHAR packet (0x0A39) - Create new character (modern clients).

  Structure (36 bytes):
  - packet_id: 2 bytes (0x0A39)
  - name: 24 bytes (character name, null-terminated)
  - slot: 1 byte (character slot)
  - hair_color: 2 bytes
  - hair_style: 2 bytes  
  - starting_job: 2 bytes (job class ID)
  - unknown: 2 bytes
  - sex: 1 byte (0 = female, 1 = male)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0A39
  @packet_size 36

  defstruct [
    :name,
    :slot,
    :hair_color,
    :hair_style,
    :starting_job,
    :unknown,
    :sex
  ]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(
        <<@packet_id::16-little, name::binary-size(24), slot::8, hair_color::16-little,
          hair_style::16-little, starting_job::16-little, unknown::16-little, sex::8>>
      ) do
    {:ok,
     %__MODULE__{
       name: extract_string(name),
       slot: slot,
       hair_color: hair_color,
       hair_style: hair_style,
       starting_job: starting_job,
       unknown: unknown,
       sex: sex
     }}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{} = packet) do
    name_binary = pack_string(packet.name, 24)

    <<
      @packet_id::16-little,
      name_binary::binary-size(24),
      packet.slot::8,
      packet.hair_color::16-little,
      packet.hair_style::16-little,
      packet.starting_job::16-little,
      packet.unknown || 0::16-little,
      packet.sex::8
    >>
  end
end
