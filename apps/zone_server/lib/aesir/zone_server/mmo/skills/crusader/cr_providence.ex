defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrProvidence do
  @moduledoc """
  Resistant Souls (CR_PROVIDENCE). Applies SC_PROVIDENCE to an ally.

  Cannot be cast on a target of the Crusader job tree (Crusader, Paladin, or
  their transcendent/baby forms), including the caster.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 256,
    name: :cr_providence,
    status: :sc_providence,
    display_name: "Resistant Souls",
    max_level: 5,
    target_type: :target_ally,
    range: 9,
    sp_cost: List.duplicate(30, 5),
    duration: List.duplicate(180_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @crusader_jobs [:crusader, :crusader2, :paladin, :paladin2, :baby_crusader, :baby_crusader2]

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :cannot_target_crusader}
  def validate(%{character_id: caster_id}, {:unit, {:homunculus, gid}}, _level, _definition) do
    with {:ok, caster_combatant} <- TargetResolver.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- TargetResolver.resolve_combatant(:homunculus, gid),
         true <- Targeting.direct_support?(caster_combatant, target_combatant) do
      :ok
    else
      _ -> {:error, :invalid_target}
    end
  end

  def validate(_caster, {:unit, {:homunculus, _gid}}, _level, _definition),
    do: {:error, :invalid_target}

  def validate(caster, target, _level, _definition) do
    target_id = Active.resolve_target_id(caster, target)

    if crusader_class?(target_id) do
      {:error, :cannot_target_crusader}
    else
      :ok
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, target, level, definition) do
    target_id = Active.resolve_target_id(caster, target)
    duration = Enum.at(definition.duration, level - 1)
    {unit_type, target_id} = target_ref(target_id)
    params = [val1: level, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(unit_type, target_id, :sc_providence, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end

  defp crusader_class?(target_id) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, state, _pid}} -> job_name(state) in @crusader_jobs
      {:error, :not_found} -> false
    end
  end

  defp job_name(state) do
    case AvailableJobs.job_id_to_name(state.stats.progression.job_id) do
      {:ok, name} -> name
      {:error, _reason} -> nil
    end
  end
end
