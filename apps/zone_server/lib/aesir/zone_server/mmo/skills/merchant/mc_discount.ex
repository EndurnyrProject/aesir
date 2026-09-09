defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McDiscount do
  @moduledoc """
  Discount (MC_DISCOUNT). Reduces prices when buying from discountable NPC shops.

  Renewal and pre-renewal agree: NPC buy prices drop by 5% plus 2% per level, minus 1% at level 10 (24% at most), and the price never goes below the shop minimum.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 37,
    name: :mc_discount,
    display_name: "Discount",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
