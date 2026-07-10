defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IntFood do
  @moduledoc """
  Food INT buff (SC_INTFOOD).

  Raises INT by `val1` for the duration. A plain additive stat bonus whose
  magnitude and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_intfood,
    properties: [:buff],
    calc_flags: [:int],
    icon: :food_int

  @impl true
  def modifiers(instance, _context), do: %{int: instance.val1}
end
