defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HfliMoon do
  @moduledoc "Moonlight, Filir's ranked multi-hit physical attack."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8009,
    name: :hfli_moon,
    display_name: "Moonlight",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 15,
    sp_cost: [4, 8, 12, 16, 20],
    cooldown: List.duplicate(2_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active
  @hit_counts [1, 2, 2, 2, 3]

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    case Combat.execute_skill_attack(caster, target,
           skill_id: definition.id,
           skill_level: level,
           skill_ratio: 100 + 10 + 110 * level,
           display_hit_count: Enum.at(@hit_counts, level - 1),
           skip_range: true,
           skip_crit: true
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
