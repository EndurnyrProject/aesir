defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoKitranslation do
  @moduledoc """
  Ki Translation (MO_KITRANSLATION), a quest skill that gives one spirit sphere
  to a currently eligible party member or to the caster themselves.

  The reference checks the party relation when the cast ends, before anything
  is spent, and a self target passes it. The sphere is spent only when the
  effect gives it away: a coin class or a destination already holding five
  spheres fails the paid effect with the requirement's items spared, and a self
  cast returns the sphere the cast held back with a fresh lifetime, so the
  caster's own count is unchanged.

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
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @coin_jobs [:gunslinger, :rebellion, :baby_gunslinger, :baby_rebellion]
  @sphere_cap 5
  @sphere_duration 600_000

  @doc """
  The cast-end relation check: another player must be in the caster's party,
  which the caster's own use passes. Nothing is spent when it fails.
  """
  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(_caster, :self, _level, _definition), do: :ok

  def validate(caster, {:unit, target_id}, _level, _definition) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target, pid}} when is_pid(pid) ->
        if target.character_id == caster.character_id, do: :ok, else: party_member(caster, target)

      _ ->
        {:error, :invalid_target}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  def cast(%PlayerState{} = caster, :self, _level, _definition) do
    if SpiritSpheres.count(caster.spirit_spheres) < @sphere_cap,
      do: {:ok, refresh_own_sphere(caster)},
      else: {:failed, caster, :invalid_target, :spare_items}
  end

  def cast(caster, {:unit, target_id}, _level, _definition) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target, pid}} when is_pid(pid) ->
        transfer(caster, target_id, target, pid)

      _not_found ->
        {:failed, caster, :invalid_target, :spare_items}
    end
  end

  # The reference refuses an ineligible destination from inside the
  # implementation with `SKILL_NOCONSUME_REQ`: its SP stays spent, the failure
  # is reported, and its items and its sphere are spared.
  defp transfer(caster, target_id, target, pid) do
    if eligible?(caster, target, pid),
      do: {:deferred, spend_sphere(caster), {:transfer_sphere, target_id}},
      else: {:failed, caster, :invalid_target, :spare_items}
  end

  defp eligible?(caster, target, pid) do
    Process.alive?(pid) and
      caster.character_id != target.character_id and
      Unit.living?(target) and
      not coin_job?(target) and
      SpiritSpheres.count(target.spirit_spheres) < @sphere_cap
  end

  # A self cast deletes one sphere and adds a fresh one to the same player, so
  # the count stays and the lifetime restarts. The reference moves spheres only
  # inside the effect, so nothing is spent when the effect refuses.
  defp refresh_own_sphere(%PlayerState{} = caster) do
    case spend_sphere(caster) do
      %PlayerState{} = spent ->
        expires_at = System.monotonic_time(:millisecond) + @sphere_duration

        case SpiritSpheres.add_if_below_cap(spent.spirit_spheres, expires_at, @sphere_cap) do
          {:ok, spheres, _entry} -> %{spent | spirit_spheres: spheres}
          {:error, :full} -> spent
        end
    end
  end

  defp spend_sphere(%PlayerState{} = caster) do
    case SpiritSpheres.consume(caster.spirit_spheres, 1) do
      {:ok, spheres, _entries} -> %{caster | spirit_spheres: spheres}
      {:error, :insufficient} -> caster
    end
  end

  defp party_member(%{party_id: party_id}, %{party_id: party_id}) when party_id != 0, do: :ok
  defp party_member(_caster, _target), do: {:error, :invalid_target}

  defp coin_job?(%{stats: %{progression: %{job_id: job_id}}}) do
    match?({:ok, job} when job in @coin_jobs, AvailableJobs.job_id_to_name(job_id))
  end
end
