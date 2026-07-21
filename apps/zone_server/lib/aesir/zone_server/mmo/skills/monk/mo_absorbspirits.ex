defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoAbsorbspirits do
  @moduledoc """
  Absorb Spirit Sphere (MO_ABSORBSPIRITS).

  Self and monster targets settle locally. Player targets use the one-shot
  exchange path and are gated by the server's current PvP policy.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 262,
    name: :mo_absorbspirits,
    display_name: "Absorb Spirit Sphere",
    max_level: 1,
    target_type: :target_any,
    range: 9,
    sp_cost: [5],
    fixed_cast_time: [500]

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active
  @coin_jobs [:gunslinger, :rebellion, :baby_gunslinger, :baby_rebellion]

  @impl Active
  def validate(_caster, :self, _level, _definition), do: :ok

  def validate(caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, target, unit_type} <- TargetResolver.resolve(target_id),
         :ok <- TargetResolver.ensure_targetable(target, unit_type) do
      validate_target(caster, target, unit_type)
    else
      _ -> {:error, :invalid_target}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  def cast(caster, :self, _level, _definition) do
    {spheres, consumed} = SpiritSpheres.clear(caster.spirit_spheres)
    reward = Formulas.absorb_player_sphere_sp(length(consumed))
    {:deferred, %{caster | spirit_spheres: spheres}, {:absorb_local, reward}}
  end

  def cast(caster, {:unit, target_id}, _level, _definition) do
    case TargetResolver.resolve(target_id) do
      {:ok, _pid, _target, :player} ->
        {:deferred, caster, {:absorb_player, target_id}}

      {:ok, _pid, target, :mob} ->
        reward =
          if :rand.uniform(100) <= Formulas.absorb_mob_activation_rate(),
            do: Formulas.absorb_mob_sp(target.mob_data.level),
            else: 0

        {:deferred, caster, {:absorb_local, reward}}

      _ ->
        {:error, :invalid_target}
    end
  end

  defp validate_target(caster, target, :player) do
    if coin_job?(target),
      do: {:error, :invalid_target},
      else: Targeting.validate_enemy(caster, target)
  end

  defp validate_target(_caster, %{mob_data: %{modes: modes}}, :mob) do
    if :status_immune in (modes || []), do: {:error, :invalid_target}, else: :ok
  end

  defp validate_target(_caster, _target, _unit_type), do: {:error, :invalid_target}

  defp coin_job?(%{stats: %{progression: %{job_id: job_id}}}) do
    match?({:ok, job} when job in @coin_jobs, AvailableJobs.job_id_to_name(job_id))
  end
end
