defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsIron do
  @moduledoc """
  Iron Tempering (BS_IRON). Refines iron from ore through the shared forge flow
  with a 45 to 65% base bonus by level.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 94,
    name: :bs_iron,
    display_name: "Iron Tempering",
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
