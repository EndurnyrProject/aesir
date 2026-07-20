defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcVulture do
  @moduledoc """
  Vulture's Eye (AC_VULTURE). Grants +1 HIT per skill level always, and +1 attack
  range per skill level while a bow is wielded.

  rAthena: AC_VULTURE passive — flat HIT bonus equal to skill level unconditionally;
  attack-range bonus equal to skill level only when weapon_type is :bow. Prereq
  Owl's Eye 3 is enforced by the skill tree (Task 13), not here.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 44,
    name: :ac_vulture,
    display_name: "Vulture's Eye",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def hit_bonus(level, _ctx), do: level

  @impl Passive
  def range_bonus(level, %{weapon_type: :bow}), do: level
  def range_bonus(_level, _ctx), do: 0
end
