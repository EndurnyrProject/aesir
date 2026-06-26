defmodule Aesir.ZoneServer.Mmo.Skills.AlIncagi do
  @moduledoc """
  Increase AGI (AL_INCAGI). Applies SC_INCREASEAGI to the target.

  rAthena: val1 = skill level, val2 = AGI bonus (2 + level).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 29,
    name: :al_incagi,
    display_name: "Increase AGI",
    max_level: 10,
    target_type: :target_ally,
    range: 9,
    sp_cost: [18, 21, 24, 27, 30, 33, 36, 39, 42, 45],
    cast_time: List.duplicate(800, 10),
    after_cast_delay: List.duplicate(400, 10),
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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, target, level, definition) do
    target_id = Active.resolve_target_id(caster, target)
    duration = Enum.at(definition.duration, level - 1)

    params = [val1: level, val2: 2 + level, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(:player, target_id, :sc_increaseagi, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
