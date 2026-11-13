defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsTracking do
  @moduledoc """
  Tracking fires a bullet for `200 + 100 * level` percent weapon damage.
  Its cast ignores DEX and status cast modifiers in both modes. Renewal casts
  in 600–1500 ms with a 1500 ms delay; pre-renewal casts in 1200–3000 ms
  without a delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 512,
    name: :gs_tracking,
    display_name: "Tracking",
    max_level: 10,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -9,
    element: :weapon,
    require_weapon: [:revolver, :rifle],
    require_ammo: [:bullet],
    ammo_qty: List.duplicate(1, 10),
    sp_cost: Enum.map(1..10, &(10 + 5 * &1)),
    ignore_dex: true,
    ignore_status_cast: true,
    cast_time: [
      renewal: Enum.map(1..10, &(500 + 100 * &1)),
      pre_renewal: Enum.map(1..10, &(1000 + 200 * &1))
    ],
    after_cast_delay: [renewal: List.duplicate(1500, 10), pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
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
      skill_ratio: 200 + 100 * level,
      hit_divisions: Definition.hit_count_at_level(definition, level),
      skip_range: true,
      skip_crit: true
    )
  end
end
