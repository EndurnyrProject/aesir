defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgRaid do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 214,
    name: :rg_raid,
    requires: [],
    display_name: "Sightless Mind",
    max_level: 5,
    target_type: :self,
    damage_type: :damage,
    splash_radius: 2

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Active

  @impl Active
  def validate(%PlayerState{character_id: caster_id}, _target, _level, _definition) do
    if StatusStorage.has_status?(:player, caster_id, :sc_hiding),
      do: :ok,
      else: {:error, :requires_hiding}
  end

  def validate(%MobState{}, _target, _level, _definition), do: :ok

  @impl Active
  def cast(%{map_name: map_name, x: x, y: y} = caster, :self, level, definition) do
    {source_type, source_id} = source = caster_ref(caster)
    StatusInterpreter.remove_status(source_type, source_id, :sc_hiding)

    result =
      map_name
      |> SpatialIndex.get_all_units_in_range(x, y, definition.splash_radius)
      |> Enum.filter(&enemy?(caster, &1))
      |> Enum.reduce_while(:ok, fn target_ref, :ok ->
        case Combat.execute_skill_attack(caster, target_ref, attack_opts(definition, level)) do
          {:ok, %{hit?: true}} ->
            apply_riders(source, target_ref, level)
            {:cont, :ok}

          {:ok, %{hit?: false}} ->
            {:cont, :ok}

          {:error, _reason} = error ->
            {:halt, error}
        end
      end)

    case result do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp attack_opts(definition, level) do
    [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 50 + 150 * level,
      skip_range: true,
      report_hit: true
    ]
  end

  defp enemy?(caster, target_ref) do
    case TargetResolver.resolve(target_ref) do
      {:ok, _pid, target, _unit_type} -> Targeting.validate_enemy(caster, target) == :ok
      _ -> false
    end
  end

  defp apply_riders({source_type, source_id}, {target_type, target_id}, level) do
    success_rate = 10 + 3 * level

    StatusInterpreter.apply_status(target_type, target_id, :sc_stun,
      success_rate: success_rate,
      caster_id: source_id,
      source_type: source_type
    )

    StatusInterpreter.apply_status(target_type, target_id, :sc_blind,
      success_rate: success_rate,
      caster_id: source_id,
      source_type: source_type
    )

    StatusInterpreter.apply_status(target_type, target_id, :sc_raid,
      success_rate: 100,
      caster_id: source_id,
      source_type: source_type
    )

    :ok
  end

  defp caster_ref(%PlayerState{character_id: caster_id}), do: {:player, caster_id}
  defp caster_ref(%MobState{instance_id: caster_id}), do: {:mob, caster_id}
end
