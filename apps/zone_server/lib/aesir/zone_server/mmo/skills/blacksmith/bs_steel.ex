defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSteel do
  @moduledoc """
  Steel Tempering (BS_STEEL). Refines steel from raw materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 95,
    name: :bs_steel,
    display_name: "Steel Tempering",
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
