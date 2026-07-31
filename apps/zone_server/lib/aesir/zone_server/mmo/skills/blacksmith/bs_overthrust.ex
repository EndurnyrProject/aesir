defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsOverthrust do
  @moduledoc """
  Power-Thrust (BS_OVERTHRUST). Temporarily increases weapon attack for the caster and nearby allies. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 113,
    name: :bs_overthrust,
    display_name: "Power-Thrust",
    max_level: 5,
    target_type: :self,
    sp_cost: [18, 16, 14, 12, 10],
    duration: [20_000, 40_000, 60_000, 80_000, 100_000],
    status: :sc_overthrust
end
