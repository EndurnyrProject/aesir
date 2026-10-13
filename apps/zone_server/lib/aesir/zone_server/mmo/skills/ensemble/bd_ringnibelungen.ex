defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRingnibelungen do
  @moduledoc """
  Harmonic Lick (BD_RINGNIBELUNGEN), an ensemble granting Ring of Nibelungen.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  as a party buff within its area; each recipient rolls its own random bonus.
  Pre-renewal: an instant cast with no cooldown for the classic SP. An adjacent
  partner maintains a stationary 9x9 field for one minute, with 1 SP upkeep every
  3 seconds each, granting `(level + 2) * 25` weapon ATK to level-4 weapons. Party
  occupants other than the performers lose the effect immediately when leaving.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 310,
    name: :bd_ringnibelungen,
    cast_cancel: [renewal: false, pre_renewal: true],
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

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Active
  def cast(caster, _target, level, definition) do
    Perform.perform(caster, definition, level, :sc_nibelungen, &status_params/1, scope: :party)
  end

  defp status_params(level) do
    case GameMode.mode() do
      :renewal -> [val1: level]
      :pre_renewal -> [val1: level, val2: (level + 2) * 25]
    end
  end
end
