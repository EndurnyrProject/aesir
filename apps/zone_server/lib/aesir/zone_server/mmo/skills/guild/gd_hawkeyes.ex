defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdHawkeyes do
  @moduledoc """
  Sharp Gaze (GD_HAWKEYES). Master aura: +DEX per level to guildmates within 2 cells of the master. Aura ticking lives in the guild aura status effects.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_009,
    name: :gd_hawkeyes,
    display_name: "Sharp Gaze",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
