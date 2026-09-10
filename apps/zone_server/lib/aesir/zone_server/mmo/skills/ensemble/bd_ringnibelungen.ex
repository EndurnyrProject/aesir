defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRingnibelungen do
  @moduledoc """
  Harmonic Lick (BD_RINGNIBELUNGEN). An ensemble adding weapon ATK for high-level weapons.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  as a party buff within its area. Pre-renewal: an instant cast with no cooldown
  for the classic SP and a 1-minute performance; the classic ground-unit model
  (a field affecting whoever stands in it while both performers keep playing) is
  deferred to a skill-unit performance subsystem.
  """

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
    sp_cost: [renewal: [64, 60, 56, 52, 48], pre_renewal: Enum.to_list(38..50//3)],
    duration: List.duplicate(60_000, 5),
    cast_time: [renewal: List.duplicate(3_000, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 5), pre_renewal: []],
    cooldown: [renewal: List.duplicate(20_000, 5), pre_renewal: []],
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
