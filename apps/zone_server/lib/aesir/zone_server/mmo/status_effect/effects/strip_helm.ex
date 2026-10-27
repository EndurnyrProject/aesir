defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripHelm do
  @moduledoc "Divest Helm (SC_STRIPHELM)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_striphelm,
    immunity: [:boss],
    metadata: %{strip_slot: :head_top},
    no_dispel: true,
    no_save: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    properties: [:debuff],
    bypass_resistance: true,
    calc_flags: [:int],
    icon: :noequiphelm

  @doc """
  A homunculus holder loses 40 percent of its INT after its additive
  bonuses; a monster's cut is part of its calculated stats, and a player only
  loses the equipment.
  """
  @impl true
  def modifiers(_instance, %{unit_type: :homunculus}), do: %{int_cut_rate: 40}
  def modifiers(_instance, _context), do: %{}
end
