defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors.SmBash do
  @moduledoc """
  Bash (SM_BASH). Single-target physical strike on an enemy.

  rAthena: base 100% + 30% per level weapon damage, weapon element, no crit.
  The stun rider (with SM_FATALBLOW, level > 5) is not modeled yet.
  """
  use Aesir.ZoneServer.Mmo.Skill.Behaviour, skill: :sm_bash

  alias Aesir.ZoneServer.Mmo.Combat

  @impl true
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 30 * level,
      skip_crit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
