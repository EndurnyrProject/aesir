defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BatkFood do
  @moduledoc """
  Food base-ATK buff (SC_BATKFOOD).

  Raises base ATK by `val1` for the duration. A plain additive bonus whose
  magnitude and duration come from the consumed item's `sc_start`. rAthena has
  no icon for this food, so none is set.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_batkfood,
    properties: [:buff],
    calc_flags: [:atk]

  @impl true
  def modifiers(instance, _context), do: %{atk: instance.val1}
end
