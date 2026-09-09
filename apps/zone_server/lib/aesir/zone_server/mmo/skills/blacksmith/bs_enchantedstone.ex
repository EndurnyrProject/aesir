defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsEnchantedstone do
  @moduledoc """
  Enchanted Stone Craft (BS_ENCHANTEDSTONE). Crafts elemental stones through the
  shared forge flow with a 15 to 35% base bonus by level, and Star Crumbs at a
  sure rate.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 96,
    name: :bs_enchantedstone,
    display_name: "Enchanted Stone Craft",
    max_level: 5,
    target_type: :self

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.ForgeSkill

  @behaviour Active
  @behaviour Menu

  @impl Active
  defdelegate cast(caster, target, level, definition), to: ForgeSkill
  @impl Menu
  defdelegate on_menu_reply(caster, selection, level), to: ForgeSkill
end
