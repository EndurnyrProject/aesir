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

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @crusader_jobs [:crusader, :crusader2, :paladin, :paladin2, :baby_crusader, :baby_crusader2]

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :cannot_target_crusader}
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
    unit_type = if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
    params = [val1: level, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(unit_type, target_id, :sc_providence, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
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
