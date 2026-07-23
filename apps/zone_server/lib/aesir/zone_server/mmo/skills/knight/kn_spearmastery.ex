defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearmastery do
  @moduledoc """
  Spear Mastery (KN_SPEARMASTERY). Grants flat weapon ATK while wielding a
  one-handed or two-handed spear, boosted further while mounted.

  Renewal: `+4` weapon ATK per level on foot, `+5` weapon ATK per level while
  riding, both gated on a one-handed or two-handed spear.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 55,
    name: :kn_spearmastery,
    display_name: "Spear Mastery",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @spear_weapon_types [:one_handed_spear, :two_handed_spear]

  @impl Passive
  def atk_bonus(level, %{weapon_type: weapon, riding: true}) when weapon in @spear_weapon_types,
    do: 5 * level

  def atk_bonus(level, %{weapon_type: weapon}) when weapon in @spear_weapon_types,
    do: 4 * level

  def atk_bonus(_level, _ctx), do: 0
end
