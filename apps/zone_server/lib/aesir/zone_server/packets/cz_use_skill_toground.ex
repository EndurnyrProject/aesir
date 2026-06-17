defmodule Aesir.ZoneServer.Packets.CzUseSkillToground do
  @moduledoc """
  CZ_USE_SKILL_TOGROUND (0x0AF4) - client requests a ground-targeted skill cast.

  Newest packetver variant (CZ_n3 in rAthena's `clif_packetdb`); earlier clients
  used 0x0116/0x0366. The trailing byte is an unknown client field and is ignored.

  Structure (11 bytes):
  - packet_id: 2 bytes (0x0AF4)
  - level: 2 bytes (selected skill level)
  - skill_id: 2 bytes
  - x: 2 bytes (target cell X, plain little-endian short - not the packed walk format)
  - y: 2 bytes (target cell Y, plain little-endian short)
  - unknown: 1 byte (ignored)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0AF4
  @packet_size 11

  @type t :: %__MODULE__{
          level: integer(),
          skill_id: integer(),
          x: integer(),
          y: integer()
        }

  defstruct [:level, :skill_id, :x, :y]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(
        <<@packet_id::16-little, level::16-little, skill_id::16-little, x::16-little,
          y::16-little, _unknown::8>>
      ) do
    {:ok, %__MODULE__{level: level, skill_id: skill_id, x: x, y: y}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
