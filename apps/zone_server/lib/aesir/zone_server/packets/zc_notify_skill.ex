defmodule Aesir.ZoneServer.Packets.ZcNotifySkill do
  @moduledoc """
  ZC_NOTIFY_SKILL (0x01DE) - shows a damaging skill effect and its damage number.

  The offensive counterpart to `ZcUseSkill` (0x011A, no-damage support skills):
  the client plays the skill animation on the target and renders the damage.

  Structure (33 bytes):
  - packet_id: 2 bytes (0x01DE)
  - skill_id: 2 bytes
  - src_id: 4 bytes (caster GID)
  - target_id: 4 bytes (target GID)
  - server_tick: 4 bytes
  - src_delay: 4 bytes (caster action motion)
  - dst_delay: 4 bytes (target damage motion)
  - damage: 4 bytes (signed)
  - skill_level: 2 bytes
  - div: 2 bytes (hit count)
  - type: 1 byte (`e_damage_type`; 6 = DMG_SINGLE, 5 = DMG_SPLASH)
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Utils.ServerTick

  @packet_id 0x01DE
  @packet_size 33

  @type t :: %__MODULE__{
          skill_id: integer(),
          skill_level: integer(),
          src_id: integer(),
          target_id: integer(),
          server_tick: integer() | nil,
          src_delay: integer(),
          dst_delay: integer(),
          damage: integer(),
          div: integer(),
          type: integer()
        }

  defstruct [
    :skill_id,
    :skill_level,
    :src_id,
    :target_id,
    :src_delay,
    :dst_delay,
    :damage,
    server_tick: nil,
    div: 1,
    type: 6
  ]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    server_tick = packet.server_tick || ServerTick.now()

    data = <<
      packet.skill_id::16-little,
      packet.src_id::32-little,
      packet.target_id::32-little,
      server_tick::32-little,
      packet.src_delay::32-little-signed,
      packet.dst_delay::32-little-signed,
      packet.damage::32-little-signed,
      packet.skill_level::16-little,
      packet.div::16-little,
      packet.type::8
    >>

    build_packet(@packet_id, data)
  end
end
