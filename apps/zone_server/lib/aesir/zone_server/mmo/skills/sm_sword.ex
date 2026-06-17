defmodule Aesir.ZoneServer.Mmo.Skills.SmSword do
  @moduledoc """
  Sword Mastery (SM_SWORD). Adds flat ATK while wielding a one-handed sword or
  dagger.

  rAthena: +4 ATK per skill level for single-handed swords/daggers.
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
