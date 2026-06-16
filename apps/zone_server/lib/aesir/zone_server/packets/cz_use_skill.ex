defmodule Aesir.ZoneServer.Packets.CzUseSkill do
  @moduledoc """
  CZ_USE_SKILL (0x0113) - client requests a targeted skill cast.

  Structure (10 bytes):
  - packet_id: 2 bytes (0x0113)
  - level: 2 bytes (selected skill level)
  - skill_id: 2 bytes
  - target_id: 4 bytes (GID of target unit)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0113
  @packet_size 10

  defstruct [:level, :skill_id, :target_id]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(
        <<@packet_id::16-little, level::16-little, skill_id::16-little, target_id::32-little>>
      ) do
    {:ok, %__MODULE__{level: level, skill_id: skill_id, target_id: target_id}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
