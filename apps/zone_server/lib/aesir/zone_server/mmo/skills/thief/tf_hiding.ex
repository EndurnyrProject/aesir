defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfHiding do
  @moduledoc """
  Hiding (TF_HIDING). Toggles SC_HIDING on the caster.

  rAthena: SP 10, self-targeted. Re-casting removes the status; a fresh
  application lasts `30000 * level` ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 51,
    name: :tf_hiding,
    requires: [:player_state],
    status: :sc_hiding,
    display_name: "Hiding",
    max_level: 10,
    target_type: :self,
    sp_cost: List.duplicate(10, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, level, _definition) do
    case StatusInterpreter.toggle_status(:player, caster_id, :sc_hiding, duration: 30_000 * level) do
      {:ok, _} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
