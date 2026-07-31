defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsKnuckle do
  @moduledoc """
  Smith Knucklebrace (BS_KNUCKLE). Forges knuckles from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 103,
    name: :bs_knuckle,
    display_name: "Smith Knucklebrace",
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
