defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ManuMatk do
  @moduledoc """
  Manuk's Faith grants `val1` percent to magic attacks against Manuk-group monsters.

  The bonus adds to equipment's matching monster-group bonus at its ordinary
  damage stage, identically in both game modes. It survives Dispel and buff
  clearing, but ends on death.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_manu_matk,
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    icon: :manu_matk

  @impl true
  def modifiers(instance, _context), do: %{{:magic_addrace2, :manuk} => instance.val1}
end
