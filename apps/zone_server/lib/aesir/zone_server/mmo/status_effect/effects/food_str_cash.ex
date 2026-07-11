defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FoodStrCash do
  @moduledoc """
  Cash STR food buff (SC_FOOD_STR_CASH).

  Raises STR by `val1` for the duration; magnitude and duration come from the
  consumed item's `sc_start`. Mirrors `db/re/status.yml` `Food_Str_Cash`, which
  is mutually exclusive with the plain STR food (`EndOnStart: Food_Str`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_food_str_cash,
    properties: [:buff],
    calc_flags: [:str],
    icon: :food_str_cash,
    end_on_start: [:sc_strfood]

  @impl true
  def modifiers(instance, _context), do: %{str: instance.val1}
end
