defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmAutoberserk do
  @moduledoc """
  Auto Berserk (SM_AUTOBERSERK). Toggles SC_AUTOBERSERK on the caster.

  Re-casting removes the status. SC_AUTOBERSERK has no duration (persistent
  toggle) so no params are passed.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 146,
    name: :sm_autoberserk,
    status: :sc_autoberserk,
    display_name: "Auto Berserk",
    max_level: 1,
    target_type: :self,
    sp_cost: [1],
    quest_skill: true,
    quest_owner_job: :swordman

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, _level, _definition) do
    case StatusInterpreter.toggle_status(:player, caster_id, :sc_autoberserk, []) do
      {:ok, _} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
