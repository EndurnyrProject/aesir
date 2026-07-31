defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline2 do
  @moduledoc """
  Advanced Adrenaline Rush (BS_ADRENALINE2). Temporarily increases attack speed for a wider range of weapon users. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 459,
    name: :bs_adrenaline2,
    display_name: "Advanced Adrenaline Rush",
    max_level: 1,
    target_type: :self,
    sp_cost: [64],
    duration: [150_000],
    status: :sc_adrenaline2,
    quest_skill: true,
    quest_owner_job: :blacksmith
end
