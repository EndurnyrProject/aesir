defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoAbsorbspirits do
  @moduledoc """
  Absorb Spirit Sphere (MO_ABSORBSPIRITS).

  Self and monster targets settle locally. Player targets use the one-shot
  exchange path and are gated by the server's current PvP policy.

  A monster that is status-immune, or that fails the 20% roll, makes the
  completed cast fail: its SP is already spent and the caster sees the skill
  failure, exactly as the reference's cast-end check does. A monster that
  accepts the roll absorbs twice its runtime level in SP and turns on the
  caster.

  Renewal: a 0.5 s fixed cast only. Pre-renewal: a 2 s cast. The 7 SP per absorbed
  sphere and the 20% monster roll for twice its level are shared.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 262,
    name: :mo_absorbspirits,
    display_name: "Absorb Spirit Sphere",
    max_level: 1,
    target_type: :target_any,
    range: 9,
    sp_cost: [5],
    cast_time: [renewal: [], pre_renewal: [2_000]],
    fixed_cast_time: [renewal: [500], pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
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

      {:ok, pid, %MobState{} = target, :mob} ->
        absorb_from_monster(caster, pid, target)

      _ ->
        {:error, :invalid_target}
    end
  end

  defp validate_target(caster, target, :player) do
    if coin_job?(target),
      do: {:error, :invalid_target},
      else: Targeting.validate_enemy_relation(caster, target)
  end

  # The reference decides at cast end, so the requirement is already spent when
  # an immune or resisting monster refuses the skill.
  defp validate_target(_caster, _target, :mob), do: :ok

  defp validate_target(_caster, _target, _unit_type), do: {:error, :invalid_target}

  defp absorb_from_monster(caster, pid, %MobState{} = target) do
    if MobState.status_immune?(target) or
         :rand.uniform(100) > Formulas.absorb_mob_activation_rate() do
      {:failed, caster, :invalid_target}
    else
      MobSession.set_target(pid, {:player, caster.character_id})
      reward = Formulas.absorb_mob_sp(MobState.get_level(target))
      {:deferred, caster, {:absorb_local, reward}}
    end
  end

  defp coin_job?(%{stats: %{progression: %{job_id: job_id}}}) do
    match?({:ok, job} when job in @coin_jobs, AvailableJobs.job_id_to_name(job_id))
  end
end
