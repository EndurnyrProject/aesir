defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FleeFood do
  @moduledoc """
  Food FLEE buff (SC_FLEEFOOD).

  Raises FLEE by `val1` for the duration. A plain additive bonus whose magnitude
  and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fleefood,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:flee],
    icon: :food_basicavoidance

  @impl true
  def modifiers(instance, _context), do: %{flee: instance.val1}
end
