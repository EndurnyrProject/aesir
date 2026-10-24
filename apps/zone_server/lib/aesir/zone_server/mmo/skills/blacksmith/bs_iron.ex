defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsIron do
  @moduledoc """
  Iron Tempering (BS_IRON). Refines iron from ore from the production list the hammers
  and the Mini Furnace open with a 45 to 65% base bonus by level.

  The skill is never cast (it declares no target type): its level gates the
  recipes and raises the success chance.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 94,
    name: :bs_iron,
    display_name: "Iron Tempering",
    max_level: 5,
    target_type: :passive,
    damage_type: :damage
end
