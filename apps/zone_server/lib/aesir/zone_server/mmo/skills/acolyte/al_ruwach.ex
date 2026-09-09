defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlRuwach do
  @moduledoc """
  Ruwach (AL_RUWACH). Applies the SC_RUWACH aura to the caster: a ten-second
  self-centred holy pulse that reveals hidden and cloaked units within two
  cells and splashes a holy magic hit on enemies in the same radius. The
  duration, tick cadence, reveal radius, and splash damage all live in the
  `sc_ruwach` status module; the skill only starts the aura.

  Renewal: single level, ten SP, instant cast and no after-cast delay; the
  splash radius is two cells and the pulse's damage is holy.

  Pre-renewal: identical. The skill carries the same level cap, cost, timings,
  radius and element in both modes, and neither the aura nor its splash has a
  mode-specific branch.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 24,
    name: :al_ruwach,
    display_name: "Ruwach",
    max_level: 1,
    target_type: :self,
    damage_kind: :magic,
    element: :holy,
    splash_radius: 2,
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
