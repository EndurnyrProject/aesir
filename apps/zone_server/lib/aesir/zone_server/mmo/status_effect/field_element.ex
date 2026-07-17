defmodule Aesir.ZoneServer.Mmo.StatusEffect.FieldElement do
  @moduledoc """
  Shared element-ratio table for the Sage element fields.

  Volcano, Deluge and Violent Gale each raise their own element's attack ratio
  by the same tabulated percentage points per skill level (rAthena's
  `enchant_eff`, `status.cpp:10996`, `11011`, `11024`). The bonus is added to
  the element table's ratio rather than multiplied into the damage
  (`battle.cpp:531-551`, renewal branch).
  """

  @enchant_eff {10, 14, 17, 19, 20}

  @doc """
  Returns the element-ratio bonus, in percentage points, for a field skill level.

  Levels outside 1..5 wrap the same way rAthena's `max((val1-1)%5, 0)` index does.
  """
  @spec enchant_bonus(integer()) :: pos_integer()
  def enchant_bonus(level) when is_integer(level) do
    elem(@enchant_eff, max(rem(level - 1, 5), 0))
  end
end
