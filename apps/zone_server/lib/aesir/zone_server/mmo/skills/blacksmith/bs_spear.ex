defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSpear do
  @moduledoc """
  Smith Spear (BS_SPEAR). Forges spears from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 104,
    name: :bs_spear,
    display_name: "Smith Spear",
    max_level: 3,
    target_type: :self
end
