defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble.Partner do
  @moduledoc """
  Finds an eligible ensemble partner from shared in-memory snapshots.

  Both modes search the square one cell around the caster. A partner is a
  living party member of the opposite performer job who knows the skill, wields
  an instrument or whip, is not sitting, can move and cast, and is not already
  performing. The partner's own skill level never changes the ensemble's level.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @range 1
  @performer_weapons [:musical, :whip]

  @doc """
  Returns the first eligible partner within one cell of the caster in the map's
  block order (`SpatialIndex.units_in_area/5`), or `:none`.
  """
  @spec find(PlayerState.t(), integer()) :: {:ok, PlayerState.t()} | :none
  def find(%PlayerState{} = caster, skill_id) do
    case performer_job(caster) do
      {:ok, caster_job} ->
        caster.map_name
        |> SpatialIndex.units_in_area(
          caster.x - @range,
          caster.y - @range,
          caster.x + @range,
          caster.y + @range
        )
        |> Enum.find_value(:none, fn
          {:player, id} -> resolve_partner(id, caster, caster_job, skill_id)
          _other -> nil
        end)

      :error ->
        :none
    end
  end

  defp resolve_partner(character_id, caster, caster_job, skill_id) do
    with {:ok, {_module, %PlayerState{} = candidate, _pid}} <-
           UnitRegistry.get_unit(:player, character_id),
         true <- eligible?(candidate, caster, caster_job, skill_id) do
      {:ok, candidate}
    else
      _ -> nil
    end
  end

  defp eligible?(candidate, caster, caster_job, skill_id) do
    candidate.character_id != caster.character_id and
      same_party?(candidate, caster) and
      opposite_performer?(candidate, caster_job) and
      PlayerStats.skill_level(candidate.stats, skill_id) > 0 and
      PlayerStats.weapon_type(candidate.stats.equipment) in @performer_weapons and
      available?(candidate)
  end

  defp available?(%PlayerState{character_id: id} = candidate) do
    candidate.action_state != :sitting and
      not StatusStorage.has_status?(:player, id, :sc_dancing) and
      StatusInterpreter.can_move?(:player, id) and
      StatusInterpreter.can_use_skill?(:player, id) and
      Unit.living?(candidate)
  end

  defp same_party?(%PlayerState{party_id: party_id}, %PlayerState{party_id: party_id}),
    do: party_id != 0

  defp same_party?(_candidate, _caster), do: false

  defp opposite_performer?(candidate, caster_job) do
    case performer_job(candidate) do
      {:ok, candidate_job} -> candidate_job != caster_job
      :error -> false
    end
  end

  defp performer_job(%PlayerState{stats: %{progression: %{job_id: job_id}}})
       when is_integer(job_id) do
    with {:ok, job_name} <- AvailableJobs.job_id_to_name(job_id),
         base_job when base_job in [:bard, :dancer] <- JobLineage.base_job(job_name) do
      {:ok, base_job}
    else
      _ -> :error
    end
  end

  defp performer_job(_caster), do: :error
end
