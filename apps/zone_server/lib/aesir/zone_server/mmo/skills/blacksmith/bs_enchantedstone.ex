defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsEnchantedstone do
  @moduledoc """
  Enchanted Stone Craft (BS_ENCHANTEDSTONE). Crafts elemental stones from raw materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 96,
    name: :bs_enchantedstone,
    display_name: "Enchanted Stone Craft",
    max_level: 5,
    target_type: :self
end
