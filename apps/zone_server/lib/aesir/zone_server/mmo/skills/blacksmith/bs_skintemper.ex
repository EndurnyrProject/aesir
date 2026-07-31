defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSkintemper do
  @moduledoc """
  Skin Tempering (BS_SKINTEMPER). Improves resistance to fire and neutral attacks. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 109,
    name: :bs_skintemper,
    display_name: "Skin Tempering",
    max_level: 5,
    target_type: :passive
end
