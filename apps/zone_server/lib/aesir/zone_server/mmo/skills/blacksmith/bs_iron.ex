defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsIron do
  @moduledoc """
  Iron Tempering (BS_IRON). Refines iron from raw materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 94,
    name: :bs_iron,
    display_name: "Iron Tempering",
    max_level: 5,
    target_type: :self
end
