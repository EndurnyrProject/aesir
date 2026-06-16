defmodule Aesir.ZoneServer.Packets.ZcSkillPostdelay do
  @moduledoc """
  ZC_SKILL_POSTDELAY (0x043D) — notifies the client of a per-skill cooldown.

  Structure (8 bytes):
  - packet_id: 2 bytes (0x043D)
  - skill_id:  2 bytes
  - tick:      4 bytes (cooldown duration in milliseconds)

  Sent SELF-only to the casting player on cooldown start so the client shows
  the cooldown sweep on the skill icon. rAthena reference: `clif_skill_cooldown`
  in `src/map/clif.cpp` (`043d <skill ID>.W <tick>.L`).
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x043D
  @packet_size 8

  defstruct [:skill_id, :tick]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{skill_id: skill_id, tick: tick}) do
    build_packet(@packet_id, <<skill_id::16-little, tick::32-little>>)
  end
end
