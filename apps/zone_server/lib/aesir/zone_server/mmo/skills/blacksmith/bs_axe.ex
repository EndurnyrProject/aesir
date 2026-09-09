defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAxe do
  @moduledoc """
  Smith Axe (BS_AXE). Forges axes through the shared forge flow, each
  level unlocking the next weapon tier.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 101,
    name: :bs_axe,
    display_name: "Smith Axe",
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
