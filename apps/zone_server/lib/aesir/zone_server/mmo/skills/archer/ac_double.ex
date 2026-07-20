defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcDouble do
  @moduledoc """
  Double Strafe (AC_DOUBLE). Two-hit ranged bow attack against a single enemy.

  rAthena: AC_DOUBLE, id 46. HitCount 2, skill_ratio 100% per hit (×2 total), no
  crit (skip_crit matches SM_BASH). Range -1 uses the weapon's own range so
  Vulture's Eye range bonus applies. Consumes 1 arrow per cast (handled by the
  cast interpreter when requires_ammo: true).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 46,
    name: :ac_double,
    display_name: "Double Strafe",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    hit_count: 2,
    requires_ammo: true,
    sp_cost: List.duplicate(12, 10),
    after_cast_delay: List.duplicate(100, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      hit_count: 2,
      skip_crit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
