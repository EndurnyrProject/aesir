defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSteel do
  @moduledoc """
  Steel Tempering (BS_STEEL). Refines steel from iron and coal from the production list
  the hammers and the Mini Furnace open with a 35 to 55% base bonus by level.

  The skill is never cast (it declares no target type): its level gates the
  recipes and raises the success chance.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 95,
    name: :bs_steel,
    display_name: "Steel Tempering",
    max_level: 5,
    target_type: :passive,
    damage_type: :damage
end
