defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripShield do
  @moduledoc "Divest Shield (SC_STRIPSHIELD)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stripshield,
    immunity: [:boss],
    metadata: %{strip_slot: :left_hand},
    no_dispel: true,
    no_save: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    properties: [:debuff],
    bypass_resistance: true,
    icon: :noequipshield

  @doc """
  A homunculus holder loses 15 percent of its DEF after its additive
  bonuses; a monster's cut is part of its calculated stats, and a player only
  loses the equipment.
  """
  @impl true
  def modifiers(_instance, %{unit_type: :homunculus}), do: %{def_cut_rate: 15}
  def modifiers(_instance, _context), do: %{}
end
