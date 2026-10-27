defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripArmor do
  @moduledoc "Divest Armor (SC_STRIPARMOR)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_striparmor,
    immunity: [:boss],
    metadata: %{strip_slot: :armor},
    no_dispel: true,
    no_save: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    properties: [:debuff],
    bypass_resistance: true,
    calc_flags: [:vit],
    icon: :noequiparmor

  @doc """
  A homunculus holder loses 40 percent of its VIT after its additive
  bonuses; a monster's cut is part of its calculated stats, and a player only
  loses the equipment.
  """
  @impl true
  def modifiers(_instance, %{unit_type: :homunculus}), do: %{vit_cut_rate: 40}
  def modifiers(_instance, _context), do: %{}
end
