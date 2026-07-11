defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FoodDexCash do
  @moduledoc """
  Cash DEX food buff (SC_FOOD_DEX_CASH).

  Raises DEX by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Food_Dex_Cash`, which
  is mutually exclusive with the plain DEX food (`EndOnStart: Food_Dex`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_food_dex_cash,
    properties: [:buff],
    calc_flags: [:dex],
    icon: :food_dex_cash,
    end_on_start: [:sc_dexfood]

  @impl true
  def modifiers(instance, _context), do: %{dex: instance.val1}
end
