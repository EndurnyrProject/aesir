defmodule Aesir.ZoneServer.Mmo.Skills.AlRuwach do
  @moduledoc """
  Ruwach (AL_RUWACH). Applies SC_RUWACH aura to the caster.

  rAthena (`skill_db` id 24): MaxLevel 1, SP 10, no cast time, no after-cast
  delay. The aura's duration, tick interval, reveal radius, and holy splash
  are all driven by the `sc_ruwach` status module (10s, 500ms tick, radius 2).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 24,
    name: :al_ruwach,
    display_name: "Ruwach",
    max_level: 1,
    target_type: :self,
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, _level, _definition) do
    case StatusInterpreter.apply_status(:player, caster_id, :sc_ruwach,
           val1: 1,
           caster_id: caster_id
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
