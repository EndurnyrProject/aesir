defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStriparmor do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 217,
    name: :rg_striparmor,
    requires: [],
    display_name: "Divest Armor",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon

  @behaviour Active

  @impl Active
  def cast(caster, target, level, definition) do
    StripCommon.cast(caster, target, level, definition, :armor, :sc_striparmor, 40)
  end
end
