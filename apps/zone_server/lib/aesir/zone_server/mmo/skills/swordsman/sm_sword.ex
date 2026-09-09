defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmSword do
  @moduledoc """
  Sword Mastery (SM_SWORD). Adds mastery ATK while wielding a one-handed sword
  or a dagger.

  Renewal: +4 mastery ATK per skill level. Mastery ATK is its own term in the
  renewal attack breakdown, added after a skill's damage ratio, so the bonus is
  never amplified by a skill's percentage.

  Pre-renewal: the same +4 per level for the same two weapon classes. Classic
  folds the bonus straight into weapon damage instead of keeping a separate
  mastery term; that placement difference belongs to the physical-attack
  formula family, not to this passive, which only reports the flat amount.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 2,
    name: :sm_sword,
    display_name: "Sword Mastery",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: weapon}) when weapon in [:one_handed_sword, :dagger],
    do: 4 * level

  def atk_bonus(_level, _ctx), do: 0
end
