defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FoodAgiCash do
  @moduledoc """
  Cash AGI food buff (SC_FOOD_AGI_CASH).

  Raises AGI by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Food_Agi_Cash`, which
  is mutually exclusive with the plain AGI food (`EndOnStart: Food_Agi`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_food_agi_cash,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:agi],
    icon: :food_agi_cash,
    end_on_start: [:sc_agifood]

  @impl true
  def modifiers(instance, _context), do: %{agi: instance.val1}
end
