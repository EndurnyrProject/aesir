defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Intravision do
  @moduledoc """
  Timed Intravision (SC_INTRAVISION).

  Renewal and pre-renewal both reveal ordinary concealment only to the holder,
  without ending another unit's concealment or changing skill target checks.
  Its sight permission is independent of val1 and combines with equipment sight.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_intravision,
    no_dispel: true,
    no_clear_buff: false,
    flags: [:no_clearance, :no_banishing_buster],
    properties: [:buff],
    icon: :clairvoyance

  @impl true
  def modifiers(_instance, _context), do: %{intravision: 1}
end
