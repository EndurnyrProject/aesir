defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmAutoberserk do
  @moduledoc """
  Auto Berserk (SM_AUTOBERSERK). A quest-granted self toggle.

  Renewal: casting it turns on a permanent carrier status; casting it again
  turns the status off. While it is on, dropping to a quarter of maximum health
  or less self-applies a level 10 taunt, giving the wounded swordsman the
  taunt's attack bonus at the cost of its defense penalty.

  Pre-renewal: the same permanent toggle, the same quarter-health trigger and
  the same level 10 taunt. Nothing here is era-gated.

  The taunt is granted when the carrier takes damage rather than by a polling
  timer, and it is not withdrawn again when health climbs back above a quarter.
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
