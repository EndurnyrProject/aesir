defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcVulture do
  @moduledoc """
  Vulture's Eye (AC_VULTURE). A passive granting one point of accuracy per skill
  level with any weapon, and one cell of attack range per skill level while a
  bow is wielded. The range half is what lets an archer outrange most melee
  monsters; because every bow skill fires from the bow's own reach, they all
  gain the extra cells too.

  Renewal folds the accuracy into the attack's own to-hit roll instead of into
  the character's HIT, so the number the client shows in the status window does
  not include it even though every swing does.

  Pre-renewal adds the same points straight to HIT, so the status window shows
  them. Both modes end up with exactly the same chance to hit; only the
  displayed HIT differs, and Aesir models the bonus as HIT in both.

  The range half carries no such split: it is a weapon-range bonus in both
  modes, and only while a bow is equipped.
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
