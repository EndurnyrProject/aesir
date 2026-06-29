defmodule Aesir.ZoneServer.Mmo.Skills.McVending do
  @moduledoc """
  Vending (MC_VENDING, id 41). Learned-only Merchant passive.

  It carries no combat or stat bonus; it exists to be learnable in the Merchant
  tree and to gate the vending flow. Its learned level parameterizes the maximum
  number of shop slots a merchant may open (`2 + level`, capped at the rAthena
  `MAX_VENDING` of 12), which the vending handler reads rather than any passive
  channel here.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 41,
    name: :mc_vending,
    display_name: "Vending",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @max_slots 12

  @doc """
  Maximum number of shop slots for the given learned `MC_VENDING` level.

  Mirrors rAthena's `vending_openvending` cap: `2 + level`, clamped to
  `MAX_VENDING` (12).
  """
  @spec max_slots(pos_integer()) :: pos_integer()
  def max_slots(level) when is_integer(level) and level > 0, do: min(2 + level, @max_slots)
end
