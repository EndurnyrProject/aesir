defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McOvercharge do
  @moduledoc """
  Overcharge (MC_OVERCHARGE). Increases prices when selling to NPC shops.

  Renewal and pre-renewal agree: NPC sell prices rise by 5% plus 2% per level, minus 1% at level 10 (24% at most).
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
