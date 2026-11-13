defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsRapidshower do
  @moduledoc """
  Rapid Shower displays five hits sharing `500 + 50 * level` percent weapon
  damage. Renewal consumes one bullet and delays 1500 ms; pre-renewal consumes
  five bullets and delays 1000 ms. Snake Eye extends its range in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 515,
    name: :gs_rapidshower,
    display_name: "Rapid Shower",
    max_level: 10,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -9,
    snake_eye_range: true,
    element: :weapon,
    hit_count: -5,
    require_weapon: [:revolver],
    require_ammo: [:bullet],
    ammo_qty: [renewal: List.duplicate(1, 10), pre_renewal: List.duplicate(5, 10)],
    sp_cost: Enum.map(1..10, &(20 + 2 * &1)),
    after_cast_delay: [renewal: List.duplicate(1500, 10), pre_renewal: List.duplicate(1000, 10)]

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
      skill_ratio: 500 + 50 * level,
      hit_divisions: Definition.hit_count_at_level(definition, level),
      skip_range: true,
      skip_crit: true
    )
  end
end
