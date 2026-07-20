defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvoke do
  @moduledoc """
  Provoke (SM_PROVOKE). Applies SC_PROVOKE to a single enemy mob.

  rAthena: val1 = skill level, val2 = ATK% increase (2 + 3*level),
  val3 = DEF% reduction (5 + 5*level). Source: status.cpp SC_PROVOKE case.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 6,
    name: :sm_provoke,
    display_name: "Provoke",
    max_level: 10,
    target_type: :target_enemy,
    range: 9,
    sp_cost: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    duration: List.duplicate(30_000, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
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
