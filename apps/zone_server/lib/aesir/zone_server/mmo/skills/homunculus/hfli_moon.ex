defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HfliMoon do
  @moduledoc """
  Moonlight, Filir's ranked multi-hit physical attack: one damage calculation
  split into the level's hit divisions.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8009,
    name: :hfli_moon,
    display_name: "Moonlight",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 15,
    hit_count: [-1, -2, -2, -2, -3],
    sp_cost: [4, 8, 12, 16, 20],
    cooldown: List.duplicate(2_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    case Combat.execute_skill_attack(caster, target,
           skill_id: definition.id,
           skill_level: level,
           skill_ratio: 100 + 10 + 110 * level,
           hit_divisions: Definition.hit_count_at_level(definition, level),
           skip_range: true,
           skip_crit: true
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
