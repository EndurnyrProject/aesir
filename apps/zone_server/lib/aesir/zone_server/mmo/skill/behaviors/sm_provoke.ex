defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors.SmProvoke do
  @moduledoc """
  Provoke (SM_PROVOKE). Applies SC_PROVOKE to a single enemy mob.

  rAthena: val1 = skill level, val2 = ATK% increase (2 + 3*level),
  val3 = DEF% reduction (5 + 5*level). Source: status.cpp SC_PROVOKE case.
  """
  use Aesir.ZoneServer.Mmo.Skill.Behaviour, skill: :sm_provoke

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @impl true
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    duration = Enum.at(definition.duration, level - 1)

    params = [
      val1: level,
      val2: 2 + 3 * level,
      val3: 5 + 5 * level,
      caster_id: caster_id,
      duration: duration
    ]

    case StatusInterpreter.apply_status(:mob, target_id, :sc_provoke, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
