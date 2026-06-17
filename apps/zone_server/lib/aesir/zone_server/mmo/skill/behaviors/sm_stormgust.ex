defmodule Aesir.ZoneServer.Mmo.Skill.Behaviors.SmStormgust do
  @moduledoc """
  Storm Gust (WZ_STORMGUST). Ground-targeted persistent skill-unit.

  Unlike a direct-damage skill, the cast itself deals no damage: it places a
  ground skill-unit at the target cell via `SkillUnit.place/4`. The unit's 5x5
  water field then ticks against enemies on its own (see
  `SkillUnit.Behaviors.WzStormgust`). SP and cooldown are deducted by the
  interpreter from the skill definition.
  """
  use Aesir.ZoneServer.Mmo.Skill.Behaviour, skill: :wz_stormgust

  alias Aesir.ZoneServer.Mmo.SkillUnit

  @impl true
  def cast(caster, {:ground, x, y}, level, _definition) do
    case SkillUnit.place(caster, :wz_stormgust, level, {x, y}) do
      {:ok, _group} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
