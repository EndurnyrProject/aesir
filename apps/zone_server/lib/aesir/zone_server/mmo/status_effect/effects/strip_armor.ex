defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripArmor do
  @moduledoc "Divest Armor (SC_STRIPARMOR)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_striparmor,
    metadata: %{strip_slot: :armor},
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    properties: [:debuff],
    bypass_resistance: true,
    calc_flags: [:vit],
    icon: :noequiparmor

  @impl true
  def modifiers(instance, _context), do: %{vit: -instance.val2}
end
