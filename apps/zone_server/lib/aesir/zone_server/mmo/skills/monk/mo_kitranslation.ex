defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoKitranslation do
  @moduledoc """
  Ki Translation (MO_KITRANSLATION), a quest skill that gives one spirit sphere
  to a currently eligible party member after the caster's resources commit.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1_015,
    name: :mo_kitranslation,
    display_name: "Ki Translation",
    max_level: 1,
    target_type: :target_ally,
    range: 9,
    sp_cost: [40],
    sphere_cost: [1],
    cast_time: [1_000],
    fixed_cast_time: [1_000],
    after_cast_delay: [1_000],
    quest_skill: true,
    quest_owner_job: :monk

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @coin_jobs [:gunslinger, :rebellion, :baby_gunslinger, :baby_rebellion]
  @sphere_cap 5

  @impl Active
  def validate(caster, {:unit, target_id}, _level, _definition) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target, pid}} when is_pid(pid) ->
        if eligible?(caster, target, pid), do: :ok, else: {:error, :invalid_target}

      _ ->
        {:error, :invalid_target}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  def cast(caster, {:unit, target_id}, _level, _definition) do
    {:deferred, caster, {:transfer_sphere, target_id}}
  end

  defp eligible?(caster, target, pid) do
    Process.alive?(pid) and
      caster.character_id != target.character_id and
      caster.map_name == target.map_name and
      caster.party_id != 0 and
      caster.party_id == target.party_id and
      Unit.living?(target) and
      not coin_job?(target) and
      SpiritSpheres.count(target.spirit_spheres) < @sphere_cap
  end

  defp coin_job?(%{stats: %{progression: %{job_id: job_id}}}) do
    match?({:ok, job} when job in @coin_jobs, AvailableJobs.job_id_to_name(job_id))
  end
end
