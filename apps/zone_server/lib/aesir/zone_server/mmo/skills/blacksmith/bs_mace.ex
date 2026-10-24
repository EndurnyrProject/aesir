defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsMace do
  @moduledoc """
  Smith Mace (BS_MACE). Forges maces from the production list the hammers and the Mini
  Furnace open, each level unlocking the next weapon tier.

  The skill is never cast (it declares no target type): its level gates the
  recipes and raises the success chance.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 102,
    name: :bs_mace,
    display_name: "Smith Mace",
    max_level: 3,
    target_type: :passive,
    damage_type: :damage
end
