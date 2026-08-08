defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStripshield do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 216,
    name: :rg_stripshield,
    requires: [],
    display_name: "Divest Shield",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon

  @behaviour Active

  @impl Active
  def cast(caster, target, level, definition) do
    StripCommon.cast(caster, target, level, definition, :left_hand, :sc_stripshield, 0)
  end
end
