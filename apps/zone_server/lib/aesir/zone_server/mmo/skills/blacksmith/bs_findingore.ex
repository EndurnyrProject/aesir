defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsFindingore do
  @moduledoc """
  Ore Discovery (BS_FINDINGORE). Enables the chance to find ore while defeating monsters.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 106,
    name: :bs_findingore,
    display_name: "Ore Discovery",
    max_level: 1,
    target_type: :passive
end
