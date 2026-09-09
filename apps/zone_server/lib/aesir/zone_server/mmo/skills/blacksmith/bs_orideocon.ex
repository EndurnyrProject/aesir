defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsOrideocon do
  @moduledoc """
  Oridecon Research (BS_ORIDEOCON). A passive adding 1% per level to the chance of
  forging level 3 weapons.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 97,
    name: :bs_orideocon,
    display_name: "Oridecon Research",
    max_level: 5,
    target_type: :passive
end
