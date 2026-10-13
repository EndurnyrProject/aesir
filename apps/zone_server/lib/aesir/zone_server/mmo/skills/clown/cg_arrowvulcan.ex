defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgArrowvulcan do
  @moduledoc """
  Arrow Vulcan strikes at nine cells using an instrument or whip and one arrow,
  displayed as nine hits. Players and mobs share the same damage path.

  Renewal uses `(500 + 100 * level) * BaseLv / 100` percent weapon damage,
  1.5 s variable plus 0.5 s fixed cast, 0.5 s delay and 1.5 s cooldown.
  Pre-renewal uses `200 + 100 * level` percent, a 2 to 3.8 s cast,
  2.8 s delay at levels 1–5 or 3 s at levels 6–10, and no cooldown.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 394,
    name: :cg_arrowvulcan,
    display_name: "Arrow Vulcan",
    max_level: 10,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: 9,
    hit_count: -9,
    require_weapon: [:musical, :whip],
    requires_ammo: true,
    sp_cost: [12, 14, 16, 18, 20, 22, 24, 26, 28, 30],
    cast_time: [
      renewal: List.duplicate(1500, 10),
      pre_renewal: Enum.map(0..9, &(2000 + 200 * &1))
    ],
    fixed_cast_time: [renewal: List.duplicate(500, 10), pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(500, 10),
      pre_renewal: List.duplicate(2800, 5) ++ List.duplicate(3000, 5)
    ],
    cooldown: [renewal: List.duplicate(1500, 10), pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Clown.Formulas
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) :: :ok
  def validate(%PlayerState{}, _target, _level, _definition), do: :ok
  def validate(%MobState{}, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target}, level, definition) do
    with :ok <- strike(caster, target, level, definition), do: {:ok, caster}
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row),
    do: strike(caster, {type, id}, level, definition)

  defp strike(caster, target, level, definition) do
    Combat.execute_skill_attack(caster, target,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: Formulas.arrow_vulcan_ratio(level, base_level(caster)),
      skip_range: true,
      skip_crit: true,
      hit_divisions: Definition.hit_count_at_level(definition, level)
    )
  end

  defp base_level(%PlayerState{stats: %{progression: %{base_level: level}}}), do: level
  defp base_level(%MobState{mob_data: %{level: level}}), do: level
end
