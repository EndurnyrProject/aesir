defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSteel do
  @moduledoc """
  Steel Tempering (BS_STEEL). Refines steel from iron and coal through the shared
  forge flow with a 35 to 55% base bonus by level.

  Renewal and pre-renewal agree.
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
