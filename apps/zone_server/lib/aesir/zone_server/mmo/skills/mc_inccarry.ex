defmodule Aesir.ZoneServer.Mmo.Skills.McInccarry do
  @moduledoc """
  Enlarge Weight Limit (MC_INCCARRY). Grants `+2000 * skill level` max weight.

  rAthena (`status.cpp:3679`): `sd->max_weight += 2000 * skill`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 36,
    name: :mc_inccarry,
    display_name: "Enlarge Weight Limit",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def max_weight_bonus(level, _ctx), do: 2000 * level
end
