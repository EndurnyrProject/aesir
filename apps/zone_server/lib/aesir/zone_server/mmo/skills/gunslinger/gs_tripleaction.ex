defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsTripleaction do
  @moduledoc """
  Triple Action consumes one coin and one ammunition unit for three hits,
  each dealing 150% weapon damage. Renewal adds a one-second action delay;
  pre-renewal has no delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 502,
    name: :gs_tripleaction,
    display_name: "Triple Action",
    max_level: 1,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -9,
    element: :weapon,
    hit_count: 3,
    require_ammo: [
      :arrow,
      :dagger,
      :bullet,
      :shell,
      :grenade,
      :shuriken,
      :kunai,
      :cannonball,
      :throw_weapon
    ],
    ammo_qty: [1],
    sp_cost: [20],
    sphere_cost: [1],
    after_cast_delay: [renewal: [1000], pre_renewal: []]

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
      skill_ratio: 100 + 50 * level,
      hit_divisions: Definition.hit_count_at_level(definition, level),
      skip_range: true,
      skip_crit: true
    )
  end
end
