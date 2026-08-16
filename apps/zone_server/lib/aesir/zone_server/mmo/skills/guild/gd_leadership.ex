defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdLeadership do
  @moduledoc """
  Great Leadership (GD_LEADERSHIP). Master aura: +STR per level to guildmates within 2 cells of the master. Aura ticking lives in the guild aura status effects.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_006,
    name: :gd_leadership,
    display_name: "Great Leadership",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
