defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcThrowarrow do
  @moduledoc "Throw Arrow (DC_THROWARROW)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 324,
    name: :dc_throwarrow,
    requires: [],
    display_name: "Throw Arrow",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: 9,
    hit_count: 1,
    requires_ammo: true,
    require_weapon: [:whip],
    sp_cost: List.duplicate(12, 5),
    cast_time: List.duplicate(500, 5),
    fixed_cast_time: List.duplicate(0, 5),
    after_cast_delay: List.duplicate(300, 5),
    cooldown: List.duplicate(0, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 110 + 40 * level,
      hit_count: 1,
      display_hit_count: 2,
      ranged: true,
      skip_range: true,
      skip_crit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
