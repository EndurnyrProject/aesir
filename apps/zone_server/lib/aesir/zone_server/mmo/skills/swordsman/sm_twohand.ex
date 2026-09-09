defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmTwohand do
  @moduledoc """
  Two-Handed Sword Mastery (SM_TWOHAND). Adds mastery ATK while wielding a
  two-handed sword.

  Renewal: +4 mastery ATK per skill level, carried in the renewal attack
  breakdown's own mastery term and therefore applied after a skill's damage
  ratio rather than being scaled by it.

  Pre-renewal: the same +4 per level for the two-handed sword. Classic adds it
  directly to weapon damage; that placement difference is owned by the
  physical-attack formula family, so this passive only reports the amount.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 3,
    name: :sm_twohand,
    display_name: "Two-Handed Sword Mastery",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: :two_handed_sword}), do: 4 * level
  def atk_bonus(_level, _ctx), do: 0
end
