defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmTwohand do
  @moduledoc """
  Two-Handed Sword Mastery (SM_TWOHAND). Adds flat ATK while wielding a
  two-handed sword.

  rAthena: +4 ATK per skill level for two-handed swords.
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
