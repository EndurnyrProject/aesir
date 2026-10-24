defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsKnuckle do
  @moduledoc """
  Smith Knucklebrace (BS_KNUCKLE). Forges knuckles from the production list the hammers
  and the Mini Furnace open, each level unlocking the next weapon tier.

  The skill is never cast (it declares no target type): its level gates the
  recipes and raises the success chance.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 103,
    name: :bs_knuckle,
    display_name: "Smith Knucklebrace",
    max_level: 3,
    target_type: :passive,
    damage_type: :damage
end
