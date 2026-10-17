defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdBattleorder do
  @moduledoc """
  Battle Orders (GD_BATTLEORDER). Master-cast guild area buff: every
  same-guild player (caster included) within 15 cells gains +5 STR/INT/DEX
  for 180s. Instant cast. Renewal: 180s cooldown. Pre-renewal: 1 SP, and the
  cast blocks the guild skills for 300s (`GuildCooldown`).
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_010,
    name: :gd_battleorder,
    display_name: "Battle Orders",
    max_level: 1,
    ignore_dex: true,
    ignore_status_cast: true,
    target_type: :self,
    splash_radius: 15,
    sp_cost: [renewal: [], pre_renewal: [1]],
    cooldown: [renewal: [180_000], pre_renewal: []],
    damage_splash: true,
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea

  @behaviour Active

  @impl Active
  def validate(caster, _target, _level, _definition), do: GuildArea.validate_master(caster)

  @impl Active
  def rearm_cooldowns(caster, level, definition, now),
    do: GuildArea.rearm_cooldowns(caster, level, definition, now)

  @impl Active
  def cast(caster, :self, _level, definition) do
    GuildArea.buff_guildmates(caster, definition.splash_radius, :sc_battleorder,
      val1: 1,
      duration: 180_000
    )

    {:ok, caster}
  end
end
