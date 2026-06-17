defmodule Aesir.ZoneServer.Packets.ZcNotifyGroundskill do
  @moduledoc """
  ZC_NOTIFY_GROUNDSKILL (0x0117) - plays a ground-targeted skill's cast animation.

  Broadcast when a ground skill-unit is placed so nearby clients render the cast
  effect at the targeted cell.

  Structure (18 bytes):
  - packet_id: 2 bytes (0x0117)
  - skill_id: 2 bytes
  - src_id: 4 bytes (caster GID)
  - level: 2 bytes (skill level)
  - x: 2 bytes (target cell X)
  - y: 2 bytes (target cell Y)
  - server_tick: 4 bytes
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Utils.ServerTick

  @packet_id 0x0117
  @packet_size 18

  @type t :: %__MODULE__{
          skill_id: integer(),
          src_id: integer(),
          level: integer(),
          x: integer(),
          y: integer(),
          server_tick: integer() | nil
        }

  defstruct [
    :skill_id,
    :src_id,
    :level,
    :x,
    :y,
    server_tick: nil
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
      packet.level::16-little,
      packet.x::16-little,
      packet.y::16-little,
      server_tick::32-little
    >>

    build_packet(@packet_id, data)
  end
end
