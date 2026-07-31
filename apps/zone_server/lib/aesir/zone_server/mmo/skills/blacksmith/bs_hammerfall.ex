defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHammerfall do
  @moduledoc """
  Hammer Fall (BS_HAMMERFALL). Strikes a small area to stun nearby enemies. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 110,
    name: :bs_hammerfall,
    display_name: "Hammer Fall",
    max_level: 5,
    target_type: :ground,
    range: 1,
    splash_radius: 2,
    sp_cost: [10],
    require_weapon: [:dagger, :one_handed_sword, :one_handed_axe, :two_handed_axe, :mace]
end
