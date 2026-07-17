defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkFood do
  @moduledoc """
  Food weapon-ATK buff (SC_WATKFOOD).

  Raises weapon ATK by `val1` for the duration. Applied as a flat weapon-attack
  bonus in the damage pipeline (unlike the stat foods, rAthena applies this one
  in C rather than via a bonus script). Magnitude and duration come from the
  consumed item's `sc_start`. rAthena has no icon for this food, so none is set.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_watkfood,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:watk]

  @impl true
  def modifiers(instance, _context), do: %{watk: instance.val1}
end
