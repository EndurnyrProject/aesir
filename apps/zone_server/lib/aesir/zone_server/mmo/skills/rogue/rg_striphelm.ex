defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStriphelm do
  @moduledoc """
  Both modes roll 5 times level plus one percent plus twice the DEX difference and
  hold the piece for the level's base time plus the DEX bonus (15 s longer on a
  monster), with a 1 s delay. Renewal: a 0.56 to 1.2 s cast plus 0.14 to 0.3 s
  fixed. Pre-renewal: a 1 s cast.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 218,
    name: :rg_striphelm,
    requires: [],
    display_name: "Divest Helm",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1,
    sp_cost: [12, 14, 16, 18, 20],
    cast_time: [renewal: [560, 720, 880, 1_140, 1_200], pre_renewal: List.duplicate(1_000, 5)],
    fixed_cast_time: [renewal: [140, 180, 220, 260, 300], pre_renewal: []],
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon

  @behaviour Active

  @impl Active
  def cast(caster, target, level, definition) do
    StripCommon.cast(caster, target, level, definition, :head_top, :sc_striphelm, 40)
  end
end
