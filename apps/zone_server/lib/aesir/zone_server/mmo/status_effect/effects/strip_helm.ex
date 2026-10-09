defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripHelm do
  @moduledoc "Divest Helm (SC_STRIPHELM)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_striphelm,
    metadata: %{strip_slot: :head_top},
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    properties: [:debuff],
    bypass_resistance: true,
    calc_flags: [:int],
    icon: :noequiphelm

  @impl true
  def modifiers(instance, _context), do: %{int: -instance.val2}
end
