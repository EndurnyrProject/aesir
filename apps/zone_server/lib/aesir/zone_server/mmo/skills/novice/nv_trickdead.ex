defmodule Aesir.ZoneServer.Mmo.Skills.Novice.NvTrickdead do
  @moduledoc """
  Play Dead (NV_TRICKDEAD). Toggles SC_TRICKDEAD on the caster.

  The caster feigns death; re-casting removes the status (the player stands back
  up). SC_TRICKDEAD has no duration (persistent toggle), so no params are passed.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 143,
    name: :nv_trickdead,
    status: :sc_trickdead,
    display_name: "Play Dead",
    max_level: 1,
    target_type: :self,
    sp_cost: [5],
    quest_skill: true,
    quest_owner_job: :novice

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, _level, _definition) do
    case StatusInterpreter.toggle_status(:player, caster_id, :sc_trickdead, []) do
      {:ok, _} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
