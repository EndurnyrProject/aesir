defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStriphelm do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 218,
    name: :rg_striphelm,
    requires: [],
    display_name: "Divest Helm",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon

  @behaviour Active

  @impl Active
  def cast(caster, target, level, definition) do
    StripCommon.cast(caster, target, level, definition, :head_top, :sc_striphelm, 40)
  end
end
