defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McDiscount do
  @moduledoc """
  Discount (MC_DISCOUNT). Reduces prices when buying from discountable NPC shops.
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
