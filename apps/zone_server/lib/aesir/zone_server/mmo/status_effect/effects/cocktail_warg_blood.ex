defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CocktailWargBlood do
  @moduledoc """
  Cocktail Warg Blood cooked-food buff (SC_COCKTAIL_WARG_BLOOD).

  Raises INT by `val1` for the duration (`db/re/status.yml`: `bInt,
  getstatus(SC_COCKTAIL_WARG_BLOOD,1)`). Magnitude and duration come from the
  consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cocktail_warg_blood,
    properties: [:buff],
    calc_flags: [:int],
    icon: :cocktail_warg_blood

  @impl true
  def modifiers(instance, _context), do: %{int: instance.val1}
end
