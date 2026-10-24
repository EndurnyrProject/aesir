defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsDagger do
  @moduledoc """
  Smith Dagger (BS_DAGGER). Forges daggers from the production list the hammers and the
  Mini Furnace open, each level unlocking the next weapon tier.

  The skill is never cast (it declares no target type): its level gates the
  recipes and raises the success chance.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 98,
    name: :bs_dagger,
    display_name: "Smith Dagger",
    max_level: 3,
    target_type: :passive,
    damage_type: :damage
end
