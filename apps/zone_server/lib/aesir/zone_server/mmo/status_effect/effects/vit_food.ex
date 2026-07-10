defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.VitFood do
  @moduledoc """
  Food VIT buff (SC_VITFOOD).

  Raises VIT by `val1` for the duration. A plain additive stat bonus whose
  magnitude and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_vitfood,
    properties: [:buff],
    calc_flags: [:vit],
    icon: :food_vit

  @impl true
  def modifiers(instance, _context), do: %{vit: instance.val1}
end
