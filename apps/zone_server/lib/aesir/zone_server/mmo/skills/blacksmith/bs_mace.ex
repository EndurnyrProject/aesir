defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsMace do
  @moduledoc """
  Smith Mace (BS_MACE). Forges maces from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 102,
    name: :bs_mace,
    display_name: "Smith Mace",
    max_level: 3,
    target_type: :self
end
