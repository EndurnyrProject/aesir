defmodule Aesir.ZoneServer.Mmo.Skills.Shared.Envenom do
  @moduledoc """
  Shared Envenom weapon hit and Poison rider.
  """

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @spec execute(map(), integer() | {atom(), integer()}, pos_integer()) ::
          {:ok, map()} | {:error, atom()}
  def execute(caster, target, level) do
    opts = [
      skill_id: 52,
      skill_level: level,
      skill_ratio: 100,
      bonus_atk: 15 * level,
      element: :poison,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target, opts) do
      {:ok, %{hit?: true}} ->
        maybe_poison(caster, target, level)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_poison(caster, target, level) do
    if :rand.uniform(100) <= 4 * level + 10 do
      {unit_type, unit_id} = target_ref(target)
      {source_type, source_id} = source_ref(caster)

      StatusInterpreter.apply_status(unit_type, unit_id, :sc_poison,
        duration: 18_000,
        caster_id: source_id,
        source_type: source_type
      )
    end

    :ok
  end

  defp source_ref(%{character_id: unit_id}), do: {:player, unit_id}
  defp source_ref(%{instance_id: unit_id}), do: {:mob, unit_id}
  defp source_ref(%{world_gid: unit_id}), do: {:homunculus, unit_id}

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
