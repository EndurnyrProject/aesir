defmodule Aesir.CharServer.Packets.ChMakeChar do
  @moduledoc """
  CH_MAKE_CHAR packet (0x0067) - Client requests character creation.

  Structure:
  - packet_type: 2 bytes (0x0067)
  - name: 24 bytes (character name)
  - str: 1 byte (strength)
  - agi: 1 byte (agility)
  - vit: 1 byte (vitality)
  - int: 1 byte (intelligence)
  - dex: 1 byte (dexterity)
  - luk: 1 byte (luck)
  - slot: 1 byte (character slot)
  - hair_color: 2 bytes
  - hair_style: 2 bytes

  Total size: 37 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0067
  @packet_size 37

  defstruct [:name, :str, :agi, :vit, :int, :dex, :luk, :slot, :hair_color, :hair_style]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, data::binary>>) do
    parse(data)
  end

  def parse(
        <<name::binary-size(24), str::8, agi::8, vit::8, int::8, dex::8, luk::8, slot::8,
          hair_color::16-little, hair_style::16-little>>
      ) do
    {:ok,
     %__MODULE__{
       name: extract_string(name),
       str: str,
       agi: agi,
       vit: vit,
       int: int,
       dex: dex,
       luk: luk,
       slot: slot,
       hair_color: hair_color,
       hair_style: hair_style
     }}
  end

  def parse(_), do: {:error, :invalid_packet}
end
