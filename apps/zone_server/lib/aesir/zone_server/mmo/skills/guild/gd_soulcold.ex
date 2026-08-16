defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdSoulcold do
  @moduledoc """
  Cold Heart (GD_SOULCOLD). Master aura: +AGI per level to guildmates within 2 cells of the master. Aura ticking lives in the guild aura status effects.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_008,
    name: :gd_soulcold,
    display_name: "Cold Heart",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
