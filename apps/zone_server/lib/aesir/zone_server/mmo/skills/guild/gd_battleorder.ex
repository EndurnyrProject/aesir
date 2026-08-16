defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdBattleorder do
  @moduledoc """
  Battle Orders (GD_BATTLEORDER). Master-cast guild area buff: every
  same-guild player (caster included) within 15 cells gains +5 STR/INT/DEX
  for 180s. Guild cooldown 180s; instant cast.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_010,
    name: :gd_battleorder,
    display_name: "Battle Orders",
    max_level: 1,
    target_type: :self,
    splash_radius: 15,
    cooldown: [180_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea

  @behaviour Active

  @impl Active
  def validate(caster, _target, _level, _definition), do: GuildArea.validate_master(caster)

  @impl Active
  def cast(caster, :self, _level, definition) do
    GuildArea.buff_guildmates(caster, definition.splash_radius, :sc_battleorder,
      val1: 1,
      duration: 180_000
    )

    {:ok, caster}
  end
end
