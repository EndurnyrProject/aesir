defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LukFood do
  @moduledoc """
  Food LUK buff (SC_LUKFOOD).

  Raises LUK by `val1` for the duration. A plain additive stat bonus whose
  magnitude and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_lukfood,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:luk],
    icon: :food_luk,
    end_on_start: [:sc_food_luk_cash]

  @impl true
  def modifiers(instance, _context), do: %{luk: instance.val1}
end
