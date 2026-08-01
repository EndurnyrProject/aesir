defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McOvercharge do
  @moduledoc """
  Overcharge (MC_OVERCHARGE). Increases prices when selling to NPC shops.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 38,
    name: :mc_overcharge,
    display_name: "Overcharge",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
