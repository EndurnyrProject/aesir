defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncAllStatus do
  @moduledoc """
  All-stats buff (SC_INCALLSTATUS).

  Raises every base stat by `val1` for the duration. Both magnitude and
  duration come from the consumed item's `sc_start` (rAthena `status.cpp`
  SC_INCALLSTATUS applies `val1` to STR/AGI/VIT/INT/DEX/LUK). rAthena defines
  no icon for it (`db/re/status.yml`), so none is set.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incallstatus,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:str, :agi, :vit, :int, :dex, :luk]

  @impl true
  def modifiers(instance, _context) do
    val1 = instance.val1
    %{str: val1, agi: val1, vit: val1, int: val1, dex: val1, luk: val1}
  end
end
