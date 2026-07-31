defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble.Partner do
  @moduledoc """
  Finds an eligible ensemble partner from shared in-memory snapshots.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @range 3
  @performer_weapons [:musical, :whip]

  @doc """
  Returns the first eligible nearby partner and the performers' averaged level.

  A missing eligible partner returns `:none` so the ensemble may proceed solo.
  """
  @spec find(PlayerState.t(), integer(), pos_integer()) ::
          {:ok, PlayerState.t(), pos_integer()} | :none
  def find(%PlayerState{} = caster, skill_id, level) do
    case performer_job(caster) do
      {:ok, caster_job} ->
        caster.map_name
        |> SpatialIndex.get_players_in_range(caster.x, caster.y, @range)
        |> Enum.find_value(:none, &resolve_partner(&1, caster, caster_job, skill_id, level))

      :error ->
        :none
    end
  end

  defp resolve_partner(character_id, caster, caster_job, skill_id, level) do
    case UnitRegistry.get_unit(:player, character_id) do
      {:ok, {_module, %PlayerState{} = candidate, _pid}} ->
        partner_result(candidate, caster, caster_job, skill_id, level)

      _ ->
        nil
    end
  end

  defp partner_result(candidate, caster, caster_job, skill_id, level) do
    if eligible?(candidate, caster, caster_job, skill_id) do
      partner_level = Learned.learned_level(candidate.stats.progression.learned_skills, skill_id)
      {:ok, candidate, div(partner_level + level, 2)}
    end
  end

  defp eligible?(candidate, caster, caster_job, skill_id) do
    candidate.character_id != caster.character_id and
      same_party?(candidate, caster) and
      opposite_performer?(candidate, caster_job) and
      Learned.learned_level(candidate.stats.progression.learned_skills, skill_id) > 0 and
      PlayerStats.weapon_type(candidate.stats.equipment) in @performer_weapons and
      candidate.action_state != :sitting and
      StatusInterpreter.can_move?(:player, candidate.character_id) and
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

  defp performer_job(%PlayerState{stats: %{progression: %{job_id: job_id}}}) do
    with {:ok, job_name} <- AvailableJobs.job_id_to_name(job_id),
         base_job when base_job in [:bard, :dancer] <- JobLineage.base_job(job_name) do
      {:ok, base_job}
    else
      _ -> :error
    end
  end
end
