defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSword do
  @moduledoc """
  Smith Sword (BS_SWORD). Forges one-handed swords from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 99,
    name: :bs_sword,
    display_name: "Smith Sword",
    max_level: 3,
    target_type: :self
end
