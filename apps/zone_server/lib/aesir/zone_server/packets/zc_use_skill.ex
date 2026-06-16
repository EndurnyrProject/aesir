defmodule Aesir.ZoneServer.Packets.ZcUseSkill do
  @moduledoc """
  ZC_USE_SKILL (0x011A) - shows a no-damage (support) skill effect on a target.

  Structure (15 bytes):
  - packet_id: 2 bytes (0x011A)
  - skill_id: 2 bytes
  - level: 2 bytes
  - dst_id: 4 bytes (target GID)
  - src_id: 4 bytes (caster GID)
  - result: 1 byte (1 = success)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x011A
  @packet_size 15

  defstruct [:skill_id, :level, :dst_id, :src_id, result: 1]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{
        skill_id: skill_id,
        level: level,
        dst_id: dst_id,
        src_id: src_id,
        result: result
      }) do
    data =
      <<skill_id::16-little, level::16-little, dst_id::32-little, src_id::32-little, result::8>>

    build_packet(@packet_id, data)
  end
end
