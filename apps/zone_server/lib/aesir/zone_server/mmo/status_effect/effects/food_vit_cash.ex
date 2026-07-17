defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FoodVitCash do
  @moduledoc """
  Cash VIT food buff (SC_FOOD_VIT_CASH).

  Raises VIT by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Food_Vit_Cash`, which
  is mutually exclusive with the plain VIT food (`EndOnStart: Food_Vit`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_food_vit_cash,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:vit],
    icon: :food_vit_cash,
    end_on_start: [:sc_vitfood]

  @impl true
  def modifiers(instance, _context), do: %{vit: instance.val1}
end
