defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoAbsorbspirits do
  @moduledoc """
  Absorb Spirit Sphere (MO_ABSORBSPIRITS).

  Self and monster targets settle locally. Player targets use the one-shot
  exchange path and are gated by the server's current PvP policy. Every
  target check is made by the effect, once the SP is spent: a coin class, a
  player that is not an enemy, or any other kind of unit fails the cast with
  the skill failure. A dead player still counts by their relation alone, as the
  reference never inspects the target's life here. Another player's Homunculus
  is refused silently before the cast begins.

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
    support: true,
    range: 9,
    sp_cost: [5],
    cast_time: [renewal: [], pre_renewal: [2_000]],
    fixed_cast_time: [renewal: [500], pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active
  @coin_jobs [:gunslinger, :rebellion, :baby_gunslinger, :baby_rebellion]

  @doc """
  A player may not absorb from another player's Homunculus; the use is
  refused silently.
  """
  @impl Active
  @spec skilluse_check(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :target_restricted}
  def skilluse_check(%{character_id: caster_id}, {:unit, {:homunculus, gid}}, _level, _def) do
    with {:ok, caster_combatant} <- TargetResolver.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- TargetResolver.resolve_combatant(:homunculus, gid),
         true <- Targeting.direct_support?(caster_combatant, target_combatant) do
      :ok
    else
      _ -> {:error, :target_restricted}
    end
  end

  def skilluse_check(_caster, _target, _level, _definition), do: :ok

  @impl Active
  def validate(_caster, :self, _level, _definition), do: :ok
  def validate(_caster, {:unit, _target_id}, _level, _definition), do: :ok
  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  def cast(caster, :self, _level, _definition) do
    {spheres, consumed} = SpiritSpheres.clear(caster.spirit_spheres)
    reward = Formulas.absorb_player_sphere_sp(length(consumed))
    {:deferred, %{caster | spirit_spheres: spheres}, {:absorb_local, reward}}
  end

  def cast(caster, {:unit, target_id}, _level, _definition) do
    case TargetResolver.resolve(target_id) do
      {:ok, _pid, target, :player} ->
        absorb_from_player(caster, target_id, target)

      {:ok, pid, %MobState{} = target, :mob} ->
        absorb_from_monster(caster, pid, target)

      {:ok, _pid, _target, _unit_type} ->
        {:failed, caster, :invalid_target}

      _ ->
        {:error, :invalid_target}
    end
  end

  # Coin classes and players that are neither the caster nor an enemy fail the
  # paid effect with the skill failure. A dead target is judged by its relation
  # only, so an enemy's spheres are still absorbed.
  defp absorb_from_player(caster, target_id, target) do
    if not coin_job?(target) and
         Targeting.validate_enemy_relation_allow_dead(caster, target) == :ok,
       do: {:deferred, caster, {:absorb_player, target_id}},
       else: {:failed, caster, :invalid_target}
  end

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
