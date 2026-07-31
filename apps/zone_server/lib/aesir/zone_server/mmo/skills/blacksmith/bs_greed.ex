defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsGreed do
  @moduledoc """
  Greed (BS_GREED). Collects nearby dropped items. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1013,
    name: :bs_greed,
    display_name: "Greed",
    max_level: 1,
    target_type: :self,
    splash_radius: 2,
    sp_cost: [10],
    quest_skill: true,
    quest_owner_job: :blacksmith
end
