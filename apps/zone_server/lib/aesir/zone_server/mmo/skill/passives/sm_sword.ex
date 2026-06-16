defmodule Aesir.ZoneServer.Mmo.Skill.Passives.SmSword do
  @moduledoc """
  Sword Mastery (SM_SWORD). Adds flat ATK while wielding a one-handed sword or
  dagger.

  rAthena: +4 ATK per skill level for single-handed swords/daggers.
  """
  use Aesir.ZoneServer.Mmo.Skill.Passive, skill: :sm_sword

  @impl true
  def atk_bonus(level, %{weapon_type: weapon}) when weapon in [:one_handed_sword, :dagger],
    do: 4 * level

  def atk_bonus(_level, _ctx), do: 0
end
