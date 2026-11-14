defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsPiercingshot do
  @moduledoc """
  Piercing Shot ignores defense and can inflict Bleeding on a surviving target.
  Renewal increases its damage with a player's rifle and shortens Bleeding.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 514,
    name: :gs_piercingshot,
    display_name: "Piercing Shot",
    max_level: 5,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -9,
    snake_eye_range: true,
    element: :weapon,
    require_weapon: [:revolver, :rifle],
    require_ammo: [:bullet],
    ammo_qty: List.duplicate(1, 5),
    sp_cost: Enum.map(1..5, &(10 + &1)),
    cast_time: [renewal: List.duplicate(1200, 5), pre_renewal: List.duplicate(1500, 5)],
    fixed_cast_time: [renewal: List.duplicate(300, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: []],
    duration: [renewal: List.duplicate(108_000, 5), pre_renewal: List.duplicate(120_000, 5)]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

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
           skill_ratio: ratio(caster, level),
           ignore_defense: true,
           skip_range: true,
           skip_crit: true,
           report_hit: true
         ) do
      {:ok, %{hit?: true, target_survives?: true}} ->
        bleed(caster, target, level, Enum.at(definition.duration, level - 1))

      {:ok, _report} ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  defp ratio(caster, level) do
    case GameMode.mode() do
      :pre_renewal -> 100 + 20 * level
      :renewal -> if rifle?(caster), do: 250 + 30 * level, else: 200 + 20 * level
    end
  end

  defp rifle?(%PlayerState{stats: %{equipment: equipment}}),
    do: Stats.weapon_type(equipment) == :rifle

  defp rifle?(_caster), do: false

  defp bleed(caster, target, level, duration) do
    with {:ok, combatant} <- TargetResolver.resolve_combatant(target) do
      StatusInterpreter.apply_status(combatant.unit_type, combatant.unit_id, :sc_bleeding,
        val1: level,
        duration: duration,
        success_rate: 3 * level,
        caster_id: caster.__struct__.get_unit_id(caster),
        source_type: caster.__struct__.get_unit_type(caster)
      )
    end

    :ok
  end
end
