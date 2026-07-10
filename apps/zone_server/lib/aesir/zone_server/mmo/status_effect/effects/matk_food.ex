defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MatkFood do
  @moduledoc """
  Food MATK buff (SC_MATKFOOD).

  Raises MATK by `val1` for the duration. A plain additive bonus whose magnitude
  and duration come from the consumed item's `sc_start`. rAthena has no icon for
  this food, so none is set.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_matkfood,
    properties: [:buff],
    calc_flags: [:matk]

  @impl true
  def modifiers(instance, _context), do: %{matk: instance.val1}
end
