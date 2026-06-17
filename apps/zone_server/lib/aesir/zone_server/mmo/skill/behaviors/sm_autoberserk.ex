defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors.SmAutoberserk do
  @moduledoc """
  Auto Berserk (SM_AUTOBERSERK). Toggles SC_AUTOBERSERK on the caster.

  Re-casting removes the status. SC_AUTOBERSERK has no duration (persistent
  toggle) so no params are passed.
  """
  use Aesir.ZoneServer.Mmo.Skill.Behaviour, skill: :sm_autoberserk

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @impl true
  def cast(%{character_id: caster_id} = caster, :self, _level, _definition) do
    case StatusInterpreter.toggle_status(:player, caster_id, :sc_autoberserk, []) do
      {:ok, _} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
