defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlBlessing do
  @moduledoc """
  Blessing (AL_BLESSING). Applies SC_BLESSING to an ally.

  The status module handles curse veto and stone cure. Undead/demon race or
  undead defense element targets receive `val2 = 0` for the rAthena half-stat path.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 34,
    name: :al_blessing,
    status: :sc_blessing,
    display_name: "Blessing",
    max_level: 10,
    target_type: :target_ally,
    range: 9,
    sp_cost: [28, 32, 36, 40, 44, 48, 52, 56, 60, 64],
    duration: [
      60_000,
      80_000,
      100_000,
      120_000,
      140_000,
      160_000,
      180_000,
      200_000,
      220_000,
      240_000
    ]

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, target, level, definition) do
    target_id = Active.resolve_target_id(caster, target)
    duration = Enum.at(definition.duration, level - 1)

    with {:ok, unit_type, val2} <- target_status_params(target, target_id, level) do
      params = [val1: level, val2: val2, caster_id: caster_id, duration: duration]

      # NOTE: Aesir has no SC_CHANGEUNDEAD player misc-attack path. When it exists, add
      # Blessing's transformed-player removal/attack branch and remove this note.
      case StatusInterpreter.apply_status(unit_type, target_id, :sc_blessing, params) do
        :ok -> {:ok, caster}
        {:error, _reason} = error -> error
      end
    end
  end

  defp target_status_params(:self, _target_id, level), do: {:ok, :player, level}

  defp target_status_params(_target, target_id, level) do
    if UnitRegistry.unit_exists?(:mob, target_id) do
      mob_status_params(target_id, level)
    else
      {:ok, :player, level}
    end
  end

  defp mob_status_params(target_id, level) do
    case TargetResolver.resolve_combatant(:mob, target_id) do
      {:ok, combatant} ->
        val2 = if undead_or_demon?(combatant), do: 0, else: level
        {:ok, :mob, val2}

      {:error, _reason} = error ->
        error
    end
  end

  defp undead_or_demon?(%{race: race} = combatant) do
    race in [:undead, :demon] or undead_element?(Map.get(combatant, :element))
  end

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false
end
