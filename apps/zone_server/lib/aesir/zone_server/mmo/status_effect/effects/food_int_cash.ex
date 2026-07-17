defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FoodIntCash do
  @moduledoc """
  Cash INT food buff (SC_FOOD_INT_CASH).

  Raises INT by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Food_Int_Cash`, which
  is mutually exclusive with the plain INT food (`EndOnStart: Food_Int`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_food_int_cash,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:int],
    icon: :food_int_cash,
    end_on_start: [:sc_intfood]

  @impl true
  def modifiers(instance, _context), do: %{int: instance.val1}
end
