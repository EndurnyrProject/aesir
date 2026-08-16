defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdEmergencyMove do
  @moduledoc """
  Emergency Move (GD_EMERGENCY_MOVE). Master-cast guild area buff: same-guild
  players within 15 cells gain +25% movement speed for 10s. Guild cooldown 60s.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_019,
    name: :gd_emergency_move,
    display_name: "Emergency Move",
    max_level: 1,
    target_type: :self,
    splash_radius: 15,
    cooldown: [60_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea

  @behaviour Active

  @impl Active
  def validate(caster, _target, _level, _definition), do: GuildArea.validate_master(caster)

  @impl Active
  def cast(caster, :self, _level, definition) do
    GuildArea.buff_guildmates(caster, definition.splash_radius, :sc_emergency_move,
      val1: 1,
      duration: 10_000
    )

    {:ok, caster}
  end
end
