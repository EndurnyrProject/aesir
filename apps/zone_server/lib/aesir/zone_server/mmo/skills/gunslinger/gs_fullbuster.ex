defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsFullbuster do
  @moduledoc """
  Full Buster fires a shotgun strike for 300 plus 100 percent per level.
  A damaging hit may Blind the caster. Classic consumes more bullets at higher levels.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 519,
    name: :gs_fullbuster,
    display_name: "Full Buster",
    max_level: 10,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -9,
    snake_eye_range: true,
    element: :weapon,
    require_weapon: [:shotgun],
    require_ammo: [:bullet],
    ammo_qty: [
      renewal: List.duplicate(2, 10),
      pre_renewal: Enum.map(1..10, &(2 * div(&1 + 1, 2)))
    ],
    sp_cost: Enum.map(1..10, &(15 + 5 * &1)),
    cast_time: [renewal: List.duplicate(800, 10), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(200, 10), pre_renewal: []],
    after_cast_delay: Enum.map(1..10, &(1000 + 200 * &1)),
    duration: List.duplicate(10_000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
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
    case Combat.execute_skill_attack(caster, target,
           skill_id: definition.id,
           skill_level: level,
           skill_ratio: 300 + 100 * level,
           skip_range: true,
           skip_crit: true,
           report_hit: true
         ) do
      {:ok, %{hit?: true, damage: damage}} when damage > 0 ->
        type = caster.__struct__.get_unit_type(caster)
        id = caster.__struct__.get_unit_id(caster)

        StatusInterpreter.apply_status(type, id, :sc_blind,
          val1: level,
          duration: Enum.at(definition.duration, level - 1),
          success_rate: 2 * level,
          caster_id: id,
          source_type: type
        )

        :ok

      {:ok, _report} ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end
end
