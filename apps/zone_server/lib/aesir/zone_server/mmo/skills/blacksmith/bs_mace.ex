defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsMace do
  @moduledoc """
  Smith Mace (BS_MACE). Forges maces from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 102,
    name: :bs_mace,
    display_name: "Smith Mace",
    max_level: 3,
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
