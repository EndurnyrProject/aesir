defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAxe do
  @moduledoc """
  Smith Axe (BS_AXE). Forges axes from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 101,
    name: :bs_axe,
    display_name: "Smith Axe",
    max_level: 3,
    target_type: :self
end
