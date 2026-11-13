defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsDust do
  @moduledoc """
  Dust strikes at 100 plus 50 percent per level and pushes surviving targets
  five cells. Pre-renewal has a one-second cast; renewal casts instantly.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 518,
    name: :gs_dust,
    display_name: "Dust",
    max_level: 10,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :weapon,
    range: 2,
    knockback: 5,
    require_weapon: [:shotgun],
    require_ammo: [:bullet],
    ammo_qty: List.duplicate(1, 10),
    sp_cost: Enum.map(1..10, &(3 * &1)),
    cast_time: [renewal: [], pre_renewal: List.duplicate(1000, 10)],
    after_cast_delay: List.duplicate(1000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    with :ok <- strike(caster, target, level, definition), do: {:ok, caster}
  end

  @impl Active
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row),
    do: strike(caster, {type, id}, level, definition)

  defp strike(caster, target, level, definition) do
    Combat.execute_skill_attack(caster, target,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 50 * level,
      skip_range: true,
      skip_crit: true,
      base_distance: definition.knockback,
      native_requires_survival: true
    )
  end
end
