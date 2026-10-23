defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoKitranslation do
  @moduledoc """
  Ki Translation (MO_KITRANSLATION), a quest skill that gives one spirit sphere
  to a currently eligible party member after the caster's resources commit.

  The party relation is checked when the cast ends, before anything is spent;
  a coin class or a target already holding five spheres fails the paid effect
  with the requirement's items spared.

  Renewal: a 1 s cast plus 1 s fixed. Pre-renewal: a 2 s cast. Both cost 40 SP,
  one sphere, and a 1 s delay.
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
    cast_time: [renewal: [1_000], pre_renewal: [2_000]],
    fixed_cast_time: [renewal: [1_000], pre_renewal: []],
    after_cast_delay: [1_000],
    quest_skill: true,
    quest_owner_job: :monk

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @coin_jobs [:gunslinger, :rebellion, :baby_gunslinger, :baby_rebellion]
  @sphere_cap 5

  @doc """
  The cast-end relation check: another player must be in the caster's party,
  and any other unit fails. Nothing is spent when it fails.
  """
  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(caster, {:unit, target_id}, _level, _definition) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target, pid}} when is_pid(pid) -> party_member(caster, target)
      _ -> {:error, :invalid_target}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  def cast(caster, {:unit, target_id}, _level, _definition) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target, pid}} when is_pid(pid) ->
        transfer(caster, target_id, target, pid)

      _not_found ->
        {:failed, caster, :invalid_target, :spare_items}
    end
  end

  # The reference refuses an ineligible target from inside the implementation
  # with `SKILL_NOCONSUME_REQ`: the requirement stays paid, the failure is
  # reported and the items (and the untransferred sphere) are spared.
  defp transfer(caster, target_id, target, pid) do
    if eligible?(caster, target, pid),
      do: {:deferred, caster, {:transfer_sphere, target_id}},
      else: {:failed, caster, :invalid_target, :spare_items}
  end

  defp eligible?(caster, target, pid) do
    Process.alive?(pid) and
      caster.character_id != target.character_id and
      Unit.living?(target) and
      not coin_job?(target) and
      SpiritSpheres.count(target.spirit_spheres) < @sphere_cap
  end

  defp party_member(%{party_id: party_id}, %{party_id: party_id}) when party_id != 0, do: :ok
  defp party_member(_caster, _target), do: {:error, :invalid_target}

  defp coin_job?(%{stats: %{progression: %{job_id: job_id}}}) do
    match?({:ok, job} when job in @coin_jobs, AvailableJobs.job_id_to_name(job_id))
  end
end
