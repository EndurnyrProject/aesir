defmodule Aesir.ZoneServer.Mmo.Skill.Passives.SmTwohand do
  @moduledoc """
  Two-Handed Sword Mastery (SM_TWOHAND). Adds flat ATK while wielding a
  two-handed sword.

  rAthena: +4 ATK per skill level for two-handed swords.
  """
  use Aesir.ZoneServer.Mmo.Skill.Passive, skill: :sm_twohand

  @impl true
  def atk_bonus(level, %{weapon_type: :two_handed_sword}), do: 4 * level
  def atk_bonus(_level, _ctx), do: 0
end
