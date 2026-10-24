defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsTwohandsword do
  @moduledoc """
  Smith Two-handed Sword (BS_TWOHANDSWORD). Forges two-handed swords from the production
  list the hammers and the Mini Furnace open, each level unlocking the next weapon tier.

  The skill is never cast (it declares no target type): its level gates the
  recipes and raises the success chance.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 100,
    name: :bs_twohandsword,
    display_name: "Smith Two-handed Sword",
    max_level: 3,
    target_type: :passive,
    damage_type: :damage
end
