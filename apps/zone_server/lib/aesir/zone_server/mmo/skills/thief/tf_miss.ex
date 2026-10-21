defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfMiss do
  @moduledoc """
  Improve Dodge (TF_MISS). Adds flat FLEE while learned.

  +3 FLEE per skill level (first-job Thief branch).

  Renewal and pre-renewal agree: +3 FLEE per level, or +4 per level once the character is a second class of the thief branch (Assassin, Rogue, and their transcendent and baby forms).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 49,
    name: :tf_miss,
    display_name: "Improve Dodge",
    max_level: 10,
    target_type: :passive,
    damage_type: :damage

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid
  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Passive

  @second_mask 0xFFF

  @impl Passive
  def flee_bonus(level, ctx), do: per_level(ctx) * level

  @doc """
  The walk haste, in percent, Improve Dodge gives a player's stats: its
  level (learned or granted) for the Assassin branch (Assassin and its transcendent, baby
  and third forms), 0 for every other job. Both modes.
  """
  @spec move_haste(map()) :: non_neg_integer()
  def move_haste(%{progression: %{job_id: job_id}} = stats) when is_integer(job_id) do
    if assassin_family?(job_id), do: PlayerStats.skill_level(stats, 49), else: 0
  end

  def move_haste(_stats), do: 0

  defp assassin_family?(job_id),
    do: Bitwise.band(JobMapid.from_job(job_id), @second_mask) == JobMapid.from_job(:assassin)

  defp per_level(%{job_id: job_id}) when is_integer(job_id) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, job} ->
        if JobLineage.base_class(job) == :thief and JobLineage.base_job(job) != :thief,
          do: 4,
          else: 3

      _unknown ->
        3
    end
  end

  defp per_level(_ctx), do: 3
end
