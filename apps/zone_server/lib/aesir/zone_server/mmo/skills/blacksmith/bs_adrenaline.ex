defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline do
  @moduledoc """
  Adrenaline Rush (BS_ADRENALINE). Temporarily increases attack speed for the caster and nearby allies. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 111,
    name: :bs_adrenaline,
    display_name: "Adrenaline Rush",
    max_level: 5,
    target_type: :self,
    sp_cost: [20, 23, 26, 29, 32],
    duration: [30_000, 60_000, 90_000, 120_000, 150_000],
    status: :sc_adrenaline,
    require_weapon: [:one_handed_axe, :two_handed_axe, :mace]
end
