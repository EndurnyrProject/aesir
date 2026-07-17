defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.HitFood do
  @moduledoc """
  Food HIT buff (SC_HITFOOD).

  Raises HIT by `val1` for the duration. A plain additive bonus whose magnitude
  and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_hitfood,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:hit],
    icon: :food_basichit

  @impl true
  def modifiers(instance, _context), do: %{hit: instance.val1}
end
