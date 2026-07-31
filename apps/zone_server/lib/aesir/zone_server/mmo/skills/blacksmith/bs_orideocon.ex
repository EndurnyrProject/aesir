defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsOrideocon do
  @moduledoc """
  Oridecon Research (BS_ORIDEOCON). Improves the chance to forge high-tier weapons.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 97,
    name: :bs_orideocon,
    display_name: "Oridecon Research",
    max_level: 5,
    target_type: :passive
end
