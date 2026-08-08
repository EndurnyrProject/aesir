defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStripweapon do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 215,
    name: :rg_stripweapon,
    requires: [],
    display_name: "Divest Weapon",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon

  @behaviour Active

  @impl Active
  def cast(caster, target, level, definition) do
    StripCommon.cast(caster, target, level, definition, :right_hand, :sc_stripweapon, 0)
  end
end
