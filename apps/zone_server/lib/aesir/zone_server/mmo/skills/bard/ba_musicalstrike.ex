defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaMusicalstrike do
  @moduledoc """
  Musical Strike (BA_MUSICALSTRIKE). A ranged instrument strike at 9 cells that
  spends one arrow.

  Renewal: 110 plus 40 per level percent repeated over two hits, a 0.5 s cast,
  a 0.3 s delay, and 12 SP. Pre-renewal: 60 plus 40 per level percent, a 1.5 s
  cast, no delay, and 2 per level minus 1 SP as one hit.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 316,
    name: :ba_musicalstrike,
    requires: [],
    display_name: "Musical Strike",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: 9,
    hit_count: [renewal: 2, pre_renewal: 1],
    requires_ammo: true,
    require_weapon: [:musical],
    sp_cost: [renewal: List.duplicate(12, 5), pre_renewal: [1, 3, 5, 7, 9]],
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1_500, 5)],
    fixed_cast_time: List.duplicate(0, 5),
    after_cast_delay: [renewal: List.duplicate(300, 5), pre_renewal: []],
    cooldown: List.duplicate(0, 5)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(level),
      hit_divisions: Definition.hit_count_at_level(definition, level),
      ranged: true,
      skip_range: true,
      skip_crit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp skill_ratio(level) do
    case GameMode.mode() do
      :renewal -> 110 + 40 * level
      :pre_renewal -> 60 + 40 * level
    end
  end
end
