defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSword do
  @moduledoc """
  Smith Sword (BS_SWORD). Forges one-handed swords from the production list the hammers
  and the Mini Furnace open, each level unlocking the next weapon tier.

  The skill is never cast (it declares no target type): its level gates the
  recipes and raises the success chance.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 99,
    name: :bs_sword,
    display_name: "Smith Sword",
    max_level: 3,
    target_type: :passive,
    damage_type: :damage
end
