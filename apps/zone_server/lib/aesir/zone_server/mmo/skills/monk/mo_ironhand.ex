defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoIronhand do
  @moduledoc """
  Iron Fists (MO_IRONHAND). Grants weapon ATK while wielding a fist or knuckle.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 259,
    name: :mo_ironhand,
    display_name: "Iron Fists",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: weapon}) when weapon in [:fist, :knuckle] do
    Formulas.iron_fists_attack_bonus(level)
  end

  def atk_bonus(_level, _ctx), do: 0
end
