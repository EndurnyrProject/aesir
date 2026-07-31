defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSteel do
  @moduledoc """
  Steel Tempering (BS_STEEL). Refines steel from raw materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 95,
    name: :bs_steel,
    display_name: "Steel Tempering",
    max_level: 5,
    target_type: :self
end
