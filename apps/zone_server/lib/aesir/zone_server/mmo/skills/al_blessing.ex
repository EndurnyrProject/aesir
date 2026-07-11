defmodule Aesir.ZoneServer.Mmo.Skills.AlBlessing do
  @moduledoc """
  Blessing (AL_BLESSING). Applies SC_BLESSING to an ally.

  The status module handles curse veto, stone cure, and the undead/demon halving path.
  rAthena: val1 = skill level (STR/INT/DEX bonus and HIT multiplier), val2 = level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 34,
    name: :al_blessing,
    status: :sc_blessing,
    display_name: "Blessing",
    max_level: 10,
    target_type: :target_ally,
    range: 9,
    sp_cost: [28, 32, 36, 40, 44, 48, 52, 56, 60, 64],
    duration: [
      60_000,
      80_000,
      100_000,
      120_000,
      140_000,
      160_000,
      180_000,
      200_000,
      220_000,
      240_000
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, target, level, definition) do
    target_id = Active.resolve_target_id(caster, target)
    duration = Enum.at(definition.duration, level - 1)

    params = [val1: level, val2: level, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(:player, target_id, :sc_blessing, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
