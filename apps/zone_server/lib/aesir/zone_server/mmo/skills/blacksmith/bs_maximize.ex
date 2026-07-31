defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsMaximize do
  @moduledoc """
  Maximize Power (BS_MAXIMIZE). Temporarily makes weapon attack damage consistent. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 114,
    name: :bs_maximize,
    display_name: "Maximize Power",
    max_level: 5,
    target_type: :self,
    sp_cost: [10],
    duration: [1_000, 2_000, 3_000, 4_000, 5_000],
    status: :sc_maximizepower
end
