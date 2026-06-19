defmodule Aesir.ZoneServer.Packets.ZcUseSkill2 do
  @moduledoc """
  ZC_USESKILL_ACK (0x0B1A) - the cast bar shown while a unit charges a skill.

  Server counterpart to rAthena `clif_skillcasting`. Sent to clients in range
  (and to the caster) when a unit begins casting a skill with a non-zero cast
  time so the client renders the cast bar with the given duration and element
  aura.

  Packet id and layout are version-sensitive; this is the `PACKETVER_RE_NUM >=
  20181212` layout (packets_struct.hpp `DEFINE_PACKET_HEADER(ZC_USESKILL_ACK,
  0x0b1a)`), which is what packetver 20211103 (our build target) speaks. The
  older 0x07FB layout omits the trailing `attackMT` field.

  Structure (29 bytes):
  - packet_id: 2 bytes (0x0B1A)
  - src_id: 4 bytes (caster GID)
  - dst_id: 4 bytes (target GID; 0 for self/ground)
  - x: 2 bytes (target cell X)
  - y: 2 bytes (target cell Y)
  - skill_id: 2 bytes
  - property: 4 bytes (element/cast aura; `e_element`)
  - cast_time: 4 bytes (cast duration in milliseconds; `delayTime`)
  - disposable: 1 byte (1 = no "[name] will use [skill]" text)
  - attack_motion_time: 4 bytes (`attackMT`)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0B1A
  @packet_size 29

  @type t :: %__MODULE__{
          src_id: non_neg_integer(),
          dst_id: non_neg_integer(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          skill_id: non_neg_integer(),
          property: non_neg_integer(),
          cast_time: non_neg_integer(),
          disposable: non_neg_integer(),
          attack_motion_time: non_neg_integer()
        }

  defstruct [
    :src_id,
    :dst_id,
    :x,
    :y,
    :skill_id,
    :property,
    :cast_time,
    disposable: 0,
    attack_motion_time: 0
  ]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    data = <<
      packet.src_id::32-little,
      packet.dst_id::32-little,
      packet.x::16-little,
      packet.y::16-little,
      packet.skill_id::16-little,
      packet.property::32-little,
      packet.cast_time::32-little,
      packet.disposable::8,
      packet.attack_motion_time::32-little
    >>

    build_packet(@packet_id, data)
  end
end
