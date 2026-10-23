defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaPangvoice do
  @moduledoc """
  Pang Voice (BA_PANGVOICE). A quest skill confusing an enemy at 9 cells with a
  2 s delay. A player caster cannot target a boss-class monster.

  Renewal: 40 SP, a 0.8 s cast plus 0.2 s fixed, a 10 s cooldown, and a 100%
  base chance of 10 s of confusion and 10 s of bleeding. Pre-renewal: 20 SP, a
  1 s cast, no cooldown, and a 70% base chance of 30 s of confusion.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    quest_skill: true,
    quest_owner_job: :bard,
    id: 1010,
    name: :ba_pangvoice,
    display_name: "Pang Voice",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 9,
    sp_cost: [renewal: [40], pre_renewal: [20]],
    cast_time: [renewal: [800], pre_renewal: [1_000]],
    fixed_cast_time: [renewal: [200], pre_renewal: []],
    after_cast_delay: [2_000],
    cooldown: [renewal: [10_000], pre_renewal: []],
    damage_kind: :misc

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc """
  A player's use on a boss-class target is refused before anything else is
  checked, with the target failure.
  """
  @impl Active
  @spec skilluse_check(Active.caster(), Active.target(), pos_integer(), term()) ::
          :ok | {:error, atom()}
  def skilluse_check(%PlayerState{}, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, target, _unit_type} <- TargetResolver.resolve(target_id) do
      if target.__struct__.is_boss?(target), do: {:error, :to_target}, else: :ok
    end
  end

  def skilluse_check(_caster, _target, _level, _definition), do: :ok

  @impl Active
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, _target, _unit_type} <- TargetResolver.resolve(target_id), do: :ok
  end

  @impl Active
  def cast(caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, _target, target_type} <- TargetResolver.resolve(target_id) do
      {caster_id, source_type} = caster_ref(caster)

      Enum.each(statuses(GameMode.mode()), fn {status, duration, rate} ->
        StatusInterpreter.apply_status(target_type, target_id, status,
          duration: duration,
          success_rate: rate,
          caster_id: caster_id,
          source_type: source_type
        )
      end)

      {:ok, caster}
    end
  end

  defp statuses(:renewal), do: [{:sc_confusion, 10_000, 100}, {:sc_bleeding, 10_000, 100}]
  defp statuses(:pre_renewal), do: [{:sc_confusion, 30_000, 70}]

  defp caster_ref(%PlayerState{character_id: caster_id}), do: {caster_id, :player}
  defp caster_ref(%MobState{instance_id: caster_id}), do: {caster_id, :mob}
end
