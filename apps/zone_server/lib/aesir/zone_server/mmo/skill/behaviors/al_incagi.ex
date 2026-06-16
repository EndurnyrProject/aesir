defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors.AlIncagi do
  @moduledoc """
  Increase AGI (AL_INCAGI). Applies SC_INCREASEAGI to the target.

  rAthena: val1 = skill level, val2 = AGI bonus (2 + level).
  """
  use Aesir.ZoneServer.Mmo.Skill.Behaviour, skill: :al_incagi

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @impl true
  def cast(%{character_id: caster_id} = caster, target, level, definition) do
    target_id = resolve_target_id(caster, target)
    duration = Enum.at(definition.duration, level - 1)

    params = [val1: level, val2: 2 + level, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(:player, target_id, :sc_increaseagi, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp resolve_target_id(%{character_id: caster_id}, :self), do: caster_id
  defp resolve_target_id(_caster, {:unit, id}), do: id
end
