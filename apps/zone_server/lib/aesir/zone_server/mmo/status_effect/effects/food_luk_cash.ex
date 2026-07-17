defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FoodLukCash do
  @moduledoc """
  Cash LUK food buff (SC_FOOD_LUK_CASH).

  Raises LUK by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Food_Luk_Cash`, which
  is mutually exclusive with the plain LUK food (`EndOnStart: Food_Luk`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_food_luk_cash,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:luk],
    icon: :food_luk_cash,
    end_on_start: [:sc_lukfood]

  @impl true
  def modifiers(instance, _context), do: %{luk: instance.val1}
end
