defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgBackstap do
  @moduledoc "Back Stab (RG_BACKSTAP), a guaranteed-hit rear melee attack."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 212,
    name: :rg_backstap,
    requires: [],
    display_name: "Back Stab",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 1,
    hit_count: 1

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_ref}, level, definition) do
    with {:ok, _pid, target, target_type} <- TargetResolver.resolve(target_ref),
         true <- Geometry.behind?(caster, target) || {:error, :must_be_behind} do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: backstab_ratio(caster, level),
        hit_count: 1,
        ignore_flee: true,
        skip_range: true,
        report_hit: true
      ]

      case Combat.execute_skill_attack(caster, target_ref, opts) do
        {:ok, %{hit?: true}} ->
          apply_stun(caster, target_type, target_ref, level)
          {:ok, caster}

        {:ok, %{hit?: false}} ->
          {:ok, caster}

        {:error, _reason} = error ->
          error
      end
    end
  end

  @doc "Returns Back Stab's Renewal weapon ratio."
  @spec backstab_ratio(PlayerState.t() | MobState.t(), pos_integer()) :: pos_integer()
  def backstab_ratio(caster, level) do
    ratio = 200 + 40 * level
    if dagger?(caster), do: div(ratio, 2), else: ratio
  end

  defp dagger?(%PlayerState{stats: %{equipment: equipment}}), do: Stats.weapon_type(equipment) == :dagger
  defp dagger?(_caster), do: false

  defp apply_stun(caster, target_type, target_ref, level) do
    {source_type, caster_id} = caster_ref(caster)

    _ =
      StatusInterpreter.apply_status(target_type, unit_id(target_ref), :sc_stun,
        duration: 4_500,
        success_rate: 5 + 2 * level,
        caster_id: caster_id,
        source_type: source_type
      )

    :ok
  end

  defp caster_ref(%PlayerState{character_id: caster_id}), do: {:player, caster_id}
  defp caster_ref(%MobState{instance_id: caster_id}), do: {:mob, caster_id}

  defp unit_id({_unit_type, unit_id}), do: unit_id
  defp unit_id(unit_id), do: unit_id
end
