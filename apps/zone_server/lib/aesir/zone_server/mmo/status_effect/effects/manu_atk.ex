defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ManuAtk do
  @moduledoc """
  Manuk's Opportunity grants `val1` percent to weapon attacks against Manuk-group monsters.

  The bonus adds to equipment's matching monster-group bonus at its ordinary
  damage stage, identically in both game modes. It survives Dispel and buff
  clearing, but ends on death.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_manu_atk,
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    icon: :manu_atk

  @impl true
  def modifiers(instance, _context), do: %{{:addrace2, :manuk} => instance.val1}
end
