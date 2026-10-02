defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHit do
  @moduledoc """
  Flat HIT buff (SC_INCHIT).

  Adds `val1` to HIT.
  Val1-driven, no icon; granted by Gospel and by item scripts. Identical in both
  game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_inchit,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:hit]

  @impl true
  def modifiers(instance, _context), do: %{hit: instance.val1}
end
