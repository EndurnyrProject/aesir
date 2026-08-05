defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsGrimtooth do
  @moduledoc """
  Grimtooth (AS_GRIMTOOTH), a target-centered ranged Katar sweep.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 137,
    name: :as_grimtooth,
    requires: [],
    display_name: "Grimtooth",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: [3, 4, 5, 6, 7],
    splash_radius: 1,
    sp_cost: List.duplicate(3, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombatTarget
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def validate(caster, {:unit, target_id}, _level, _definition) do
    if TrapCombatTarget.targetable?({:skill_unit, target_id}) do
      {:error, :invalid_target}
    else
      validate_player_requirements(caster)
    end
  end

  defp validate_player_requirements(%PlayerState{
         character_id: id,
         stats: %{equipment: equipment}
       }) do
    cond do
      Stats.weapon_type(equipment) != :katar -> {:error, :katar_not_equipped}
      not StatusStorage.has_status?(:player, id, :sc_hiding) -> {:error, :hiding_required}
      true -> :ok
    end
  end

  defp validate_player_requirements(%MobState{}), do: :ok

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, _target_type, {x, y, _map_name}} <- Combat.resolve_target_position(target_id) do
      connected_targets =
        Combat.execute_splash_attack(caster, {x, y}, definition.splash_radius,
          skill_id: definition.id,
          skill_level: level,
          skill_ratio: skill_ratio(level),
          hit_count: 1,
          skip_crit: true,
          ranged: true,
          typed_results: true,
          target_skill_units: true
        )

      apply_quagmire(connected_targets, caster, level)
      {:ok, caster}
    end
  end

  defp apply_quagmire(targets, caster, level) do
    source = caster.__struct__.to_combatant(caster)

    targets
    |> Enum.filter(fn
      {:mob, target_id} -> not status_immune?(target_id)
      _other -> false
    end)
    |> Enum.each(fn {:mob, target_id} ->
      StatusInterpreter.apply_status(:mob, target_id, :sc_quagmire,
        duration: 1_000,
        level: level,
        val1: level,
        val2: 10 * level,
        caster_id: source.unit_id,
        source_type: source.unit_type
      )
    end)
  end

  defp status_immune?(target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, %MobState{mob_data: mob_data}, _pid}} ->
        :status_immune in List.wrap(Map.get(mob_data, :modes))

      _unavailable ->
        false
    end
  end

  @doc "The weapon-damage ratio at `level`."
  @spec skill_ratio(pos_integer()) :: pos_integer()
  def skill_ratio(level), do: 100 + 20 * level
end
