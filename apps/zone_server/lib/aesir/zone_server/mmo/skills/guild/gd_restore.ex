defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdRestore do
  @moduledoc """
  Restoration (GD_RESTORE). Master-cast guild area heal: every same-guild
  player (caster included) within 15 cells recovers 90% of max HP and SP.
  Renewal: 1s fixed cast, 180s cooldown. Pre-renewal: 10s variable cast,
  1 SP, and the cast blocks the guild skills for 300s (`GuildCooldown`).
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_012,
    name: :gd_restore,
    display_name: "Restoration",
    max_level: 1,
    ignore_status_cast: true,
    ignore_item_cast: true,
    target_type: :self,
    splash_radius: 15,
    sp_cost: [renewal: [], pre_renewal: [1]],
    cast_time: [renewal: [], pre_renewal: [10_000]],
    fixed_cast_time: [renewal: [1_000], pre_renewal: []],
    cooldown: [renewal: [180_000], pre_renewal: []],
    damage_splash: true

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
    caster
    |> GuildArea.guildmates_in_range(definition.splash_radius)
    |> Enum.each(&GuildArea.percent_restore(&1, 90, 90, caster.character_id))

    {:ok, caster}
  end
end
