defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsTwohandsword do
  @moduledoc """
  Smith Two-handed Sword (BS_TWOHANDSWORD). Forges two-handed swords from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 100,
    name: :bs_twohandsword,
    display_name: "Smith Two-handed Sword",
    max_level: 3,
    target_type: :self
end
