defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaDragonology do
  @moduledoc """
  Dragonology (SA_DRAGONOLOGY). A passive granting (level plus 1)/2 INT, 4% per
  level physical and 2% per level magic damage against dragons, and 4% per level
  less damage taken from them; the damage riders are read from the combatant's
  precomputed level in the damage calculators.

  Renewal and pre-renewal agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 284,
    name: :sa_dragonology,
    display_name: "Dragonology",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def int_bonus(level, _ctx), do: div(level + 1, 2)
end
