defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaPoembragi do
  @moduledoc "A Poem of Bragi (BA_POEMBRAGI)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 321,
    name: :ba_poembragi,
    display_name: "A Poem of Bragi",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: Enum.to_list(65..110//5),
    duration: List.duplicate(180_000, 10),
    cast_time: List.duplicate(1_000, 10),
    fixed_cast_time: List.duplicate(300, 10),
    after_cast_delay: List.duplicate(300, 10),
    cooldown: List.duplicate(20_000, 10),
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot

  @impl Active
  def cast(caster, :self, level, definition) do
    Snapshot.snapshot(
      caster,
      definition,
      level,
      :sc_poembragi,
      [val2: 2 * level, val3: 3 * level],
      []
    )
  end
end
