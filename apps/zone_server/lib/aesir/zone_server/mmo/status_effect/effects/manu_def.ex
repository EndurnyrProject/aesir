defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ManuDef do
  @moduledoc """
  Manuk's Courage grants `val1` percent to damage resistance against Manuk-group monsters.

  The bonus adds to equipment's matching monster-group bonus at its ordinary
  damage stage, identically in both game modes. It survives Dispel and buff
  clearing, but ends on death.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_manu_def,
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    icon: :manu_def

  @impl true
  def modifiers(instance, _context), do: %{{:subrace2, :manuk} => instance.val1}
end
