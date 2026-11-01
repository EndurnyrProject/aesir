defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SplAtk do
  @moduledoc """
  Pinguicula's Fruit Jam grants `val1` percent to weapon attacks against Splendide-group monsters.

  The bonus adds to equipment's matching monster-group bonus at its ordinary
  damage stage, identically in both game modes. It survives Dispel and buff
  clearing, but ends on death.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_spl_atk,
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    icon: :spl_atk

  @impl true
  def modifiers(instance, _context), do: %{{:addrace2, :splendide} => instance.val1}
end
