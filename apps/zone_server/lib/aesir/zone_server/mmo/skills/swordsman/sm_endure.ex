defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmEndure do
  @moduledoc """
  Endure (SM_ENDURE). Self-casts SC_ENDURE.

  rAthena: val1 = skill level (MDEF bonus), duration per level from skill_db.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 8,
    name: :sm_endure,
    requires: [:player_state],
    status: :sc_endure,
    display_name: "Endure",
    max_level: 10,
    target_type: :self,
    sp_cost: List.duplicate(10, 10),
    cooldown: List.duplicate(10_000, 10),
    duration: [
      10_000,
      13_000,
      16_000,
      19_000,
      22_000,
      25_000,
      28_000,
      31_000,
      34_000,
      37_000
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    duration = Enum.at(definition.duration, level - 1)
    params = [val1: level, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_endure, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
