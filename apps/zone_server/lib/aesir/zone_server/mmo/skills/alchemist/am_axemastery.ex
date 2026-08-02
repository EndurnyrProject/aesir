defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAxemastery do
  @moduledoc """
  Axe Mastery (AM_AXEMASTERY). Grants flat weapon ATK while wielding a one-handed
  axe, two-handed axe, or one-handed sword.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 226,
    name: :am_axemastery,
    display_name: "Axe Mastery",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @weapon_types [:one_handed_axe, :two_handed_axe, :one_handed_sword]

  @impl Passive
  def atk_bonus(level, %{weapon_type: weapon}) when weapon in @weapon_types, do: 3 * level

  def atk_bonus(_level, _ctx), do: 0
end
