defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSkintemper do
  @moduledoc """
  Skin Tempering (BS_SKINTEMPER). An always-on passive that reduces fire damage
  by 5% per level and neutral damage by 1% per level.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  use Aesir.ZoneServer.Mmo.Skill,
    id: 109,
    name: :bs_skintemper,
    display_name: "Skin Tempering",
    max_level: 5,
    target_type: :passive

  @behaviour Passive
end
