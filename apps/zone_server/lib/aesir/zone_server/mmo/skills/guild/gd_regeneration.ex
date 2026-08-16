defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdRegeneration do
  @moduledoc """
  Regeneration (GD_REGENERATION). Master-cast guild area buff: same-guild
  players within 15 cells regenerate faster for 60s - HP rate +200/+200/+300
  percent and SP rate +100/+200/+300 percent by level. Guild cooldown 180s.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_011,
    name: :gd_regeneration,
    display_name: "Regeneration",
    max_level: 3,
    target_type: :self,
    splash_radius: 15,
    cooldown: List.duplicate(180_000, 3)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea

  @behaviour Active

  @impl Active
  def validate(caster, _target, _level, _definition), do: GuildArea.validate_master(caster)

  @impl Active
  def cast(caster, :self, level, definition) do
    GuildArea.buff_guildmates(caster, definition.splash_radius, :sc_regeneration,
      val1: level,
      duration: 60_000
    )

    {:ok, caster}
  end
end
