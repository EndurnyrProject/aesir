defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsKnuckle do
  @moduledoc """
  Smith Knucklebrace (BS_KNUCKLE). Forges knuckles from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 103,
    name: :bs_knuckle,
    display_name: "Smith Knucklebrace",
    max_level: 3,
    target_type: :self
end
