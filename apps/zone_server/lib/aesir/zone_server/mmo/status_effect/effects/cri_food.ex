defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CriFood do
  @moduledoc """
  Food CRIT buff (SC_CRIFOOD).

  Raises the critical rate by `val1` for the duration. A plain additive bonus
  whose magnitude and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_crifood,
    properties: [:buff],
    calc_flags: [:critical],
    icon: :food_criticalsuccessvalue

  @impl true
  def modifiers(instance, _context), do: %{critical: instance.val1}
end
