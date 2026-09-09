defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsFindingore do
  @moduledoc """
  Ore Discovery (BS_FINDINGORE). A passive that lets defeated monsters drop ore.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 106,
    name: :bs_findingore,
    display_name: "Ore Discovery",
    max_level: 1,
    target_type: :passive
end
