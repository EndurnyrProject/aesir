defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsEnchantedstone do
  @moduledoc """
  Enchanted Stone Craft (BS_ENCHANTEDSTONE). Crafts elemental stones through the shared
  forge flow with a 15 to 35% base bonus by level, and Star Crumbs at a sure rate.

  The skill is never cast (it declares no target type): its level gates the
  recipes and raises the success chance.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 96,
    name: :bs_enchantedstone,
    display_name: "Enchanted Stone Craft",
    max_level: 5,
    target_type: :passive,
    damage_type: :damage
end
