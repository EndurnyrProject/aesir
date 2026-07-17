defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Windweapon do
  @moduledoc """
  Lightning Loader (SC_WINDWEAPON).

  Endows the weapon with the wind element, replacing other weapon endows.

  Every endow contributes the same `attack_element` modifier and aggregation
  sums colliding keys, so the endows list each other in `end_on_start`
  (replace-on-cast) to keep two of them from ever being live at once.

  rAthena ends this status when the endowed weapon is unequipped
  (`RemoveOnUnequipWeapon`). Aesir has no equipment-change hook for statuses,
  so the endow currently survives a weapon swap.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_windweapon,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk_ele],
    end_on_start: [
      :sc_aspersio,
      :sc_encpoison,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon,
      :sc_watk_element
    ],
    icon: :propertywind

  @impl true
  def modifiers(_instance, _context), do: %{attack_element: :wind}
end
