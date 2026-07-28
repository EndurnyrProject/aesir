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

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Song

  @behaviour Active

  @impl Active
  def dynamic_cost(caster, _target, level, definition),
    do: Cost.resolve(caster, definition, level)

  @impl Active
  def cast(caster, :self, level, _definition) do
    Song.snapshot(caster, 321, level, :sc_poembragi,
      val2: 2 * level,
      val3: 3 * level
    )
  end
end
