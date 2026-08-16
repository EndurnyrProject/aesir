defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdGlorywounds do
  @moduledoc """
  Glorious Wounds (GD_GLORYWOUNDS). Master aura: +VIT per level to guildmates within 2 cells of the master. Aura ticking lives in the guild aura status effects.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_007,
    name: :gd_glorywounds,
    display_name: "Glorious Wounds",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
