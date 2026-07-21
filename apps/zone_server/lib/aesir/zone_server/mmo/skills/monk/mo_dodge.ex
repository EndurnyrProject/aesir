defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoDodge do
  @moduledoc """
  Dodge (MO_DODGE). Grants FLEE while learned.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 265,
    name: :mo_dodge,
    display_name: "Dodge",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas

  @behaviour Passive

  @impl Passive
  def flee_bonus(level, _ctx), do: Formulas.dodge_flee_bonus(level)
end
