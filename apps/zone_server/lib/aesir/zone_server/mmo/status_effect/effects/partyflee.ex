defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Partyflee do
  @moduledoc """
  Party Flee's transient status in renewal and pre-renewal.

  Supplies ten FLEE per level only when a qualifying calculation observes it.
  Starting and ending the status select no stat channels; the skill's ordinary
  zero-duration start expires after one millisecond rather than remaining held.
  It can be dispelled or cleared, but survives Clearance and Banishing Buster.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_partyflee,
    no_dispel: false,
    no_clear_buff: false,
    flags: [:no_clearance, :no_banishing_buster],
    properties: [:buff],
    icon: :partyflee

  @impl true
  def modifiers(instance, _context), do: %{flee: instance.val1 * 10}
end
