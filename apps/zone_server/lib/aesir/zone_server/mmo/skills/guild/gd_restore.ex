defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdRestore do
  @moduledoc """
  Restoration (GD_RESTORE). Master-cast guild area heal: every same-guild
  player (caster included) within 15 cells recovers 90% of max HP and SP.
  1s fixed cast; guild cooldown 180s.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_012,
    name: :gd_restore,
    display_name: "Restoration",
    max_level: 1,
    target_type: :self,
    splash_radius: 15,
    fixed_cast_time: [1_000],
    cooldown: [180_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea

  @behaviour Active

  @impl Active
  def validate(caster, _target, _level, _definition), do: GuildArea.validate_master(caster)

  @impl Active
  def cast(caster, :self, _level, definition) do
    caster
    |> GuildArea.guildmates_in_range(definition.splash_radius)
    |> Enum.each(&GuildArea.percent_restore(&1, 90, 90, caster.character_id))

    {:ok, caster}
  end
end
