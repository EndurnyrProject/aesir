defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncFlee do
  @moduledoc """
  Flat FLEE buff (SC_INCFLEE).

  Adds `val1` to FLEE.
  Val1-driven, no icon; granted by Gospel and by item scripts. Identical in both
  game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incflee,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:flee]

  @impl true
  def modifiers(instance, _context), do: %{flee: instance.val1}
end
