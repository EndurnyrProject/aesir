defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsUnfairlytrick do
  @moduledoc """
  Unfair Trick (BS_UNFAIRLYTRICK). Provides a special chance-based utility effect. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1012,
    name: :bs_unfairlytrick,
    display_name: "Unfair Trick",
    max_level: 1,
    target_type: :self,
    quest_skill: true,
    quest_owner_job: :blacksmith
end
