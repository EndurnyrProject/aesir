defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HamiSkin do
  @moduledoc "Adamantium Skin (HAMI_SKIN) passive marker."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8007,
    name: :hami_skin,
    display_name: "Adamantium Skin",
    max_level: 5,
    target_type: :passive

  @behaviour Aesir.ZoneServer.Mmo.Skill.Passive
end
