defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRingnibelungen do
  @moduledoc "Ring of Nibelungen (BD_RINGNIBELUNGEN)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 310,
    name: :bd_ringnibelungen,
    display_name: "Ring of Nibelungen",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :misc,
    hit_count: 1,
    splash_radius: 15,
    sp_cost: [64, 60, 56, 52, 48],
    duration: List.duplicate(60_000, 5),
    cast_time: List.duplicate(3_000, 5),
    fixed_cast_time: List.duplicate(500, 5),
    after_cast_delay: List.duplicate(300, 5),
    cooldown: List.duplicate(20_000, 5),
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Nibelungen

  @impl Active
  def cast(caster, _target, level, definition) do
    Perform.perform(
      caster,
      definition,
      level,
      :sc_nibelungen,
      fn _level -> [state: %{rng: &Nibelungen.roll/1}] end,
      scope: :party
    )
  end
end
