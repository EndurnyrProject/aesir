defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors.SmMagnum do
  @moduledoc """
  Magnum Break (SM_MAGNUM). Self-centered splash fire strike.

  Deals fire-element splash damage to every enemy within range of the caster's
  own cell, knocks each hit target back, and self-applies SC_WATK_ELEMENT (fire)
  for the buff duration. The 2000ms cooldown is applied by the interpreter from
  the definition.

  rAthena (skill_db id 7): SplashArea 2 (5x5), Knockback 2, Element Fire,
  default 100% weapon ratio, Duration2 10000ms endow buff.
  """
  use Aesir.ZoneServer.Mmo.Skill.Behaviour, skill: :sm_magnum

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @splash_radius 2
  @knockback_distance 2
  @fire_element 3

  @impl true
  def cast(%{character_id: caster_id, x: x, y: y} = caster, :self, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      skip_crit: true
    ]

    caster
    |> Combat.execute_splash_attack({x, y}, @splash_radius, opts)
    |> Enum.each(&Combat.knockback(:mob, &1, x, y, @knockback_distance))

    duration = Enum.at(definition.duration, level - 1)
    params = [val1: @fire_element, caster_id: caster_id, duration: duration]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_watk_element, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
