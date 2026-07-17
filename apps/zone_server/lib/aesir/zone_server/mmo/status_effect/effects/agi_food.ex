defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AgiFood do
  @moduledoc """
  Food AGI buff (SC_AGIFOOD).

  Raises AGI by `val1` for the duration. Unlike Increase AGI, food grants no
  attack-speed or haste bonus; it is a plain additive stat bonus whose magnitude
  and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_agifood,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:agi],
    icon: :food_agi,
    end_on_start: [:sc_food_agi_cash]

  @impl true
  def modifiers(instance, _context), do: %{agi: instance.val1}
end
