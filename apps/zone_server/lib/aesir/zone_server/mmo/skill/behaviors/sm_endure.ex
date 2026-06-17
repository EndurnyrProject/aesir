defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors.SmEndure do
  @moduledoc """
  Endure (SM_ENDURE). Self-casts SC_ENDURE.

  rAthena: val1 = skill level (MDEF bonus), duration per level from skill_db.
  """
  use Aesir.ZoneServer.Mmo.Skill.Behaviour, skill: :sm_endure

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @impl true
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    duration = Enum.at(definition.duration, level - 1)
    params = [val1: level, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_endure, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
