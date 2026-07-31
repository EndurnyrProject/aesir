defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSword do
  @moduledoc """
  Smith Sword (BS_SWORD). Forges one-handed swords from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 99,
    name: :bs_sword,
    display_name: "Smith Sword",
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
