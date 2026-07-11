defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DexFood do
  @moduledoc """
  Food DEX buff (SC_DEXFOOD).

  Raises DEX by `val1` for the duration. A plain additive stat bonus whose
  magnitude and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_dexfood,
    properties: [:buff],
    calc_flags: [:dex],
    icon: :food_dex,
    end_on_start: [:sc_food_dex_cash]

  @impl true
  def modifiers(instance, _context), do: %{dex: instance.val1}
end
