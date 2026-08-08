defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fireweapon do
  @moduledoc """
  Flame Launcher (SC_FIREWEAPON).

  Endows the weapon with the fire element, replacing other weapon endows.

  Every endow contributes the same `attack_element` modifier and aggregation
  sums colliding keys, so the endows list each other in `end_on_start`
  (replace-on-cast) to keep two of them from ever being live at once.

  rAthena ends this status when the endowed weapon is unequipped
  (`RemoveOnUnequipWeapon`), which the equipment handler enforces off the
  `:remove_on_unequip_weapon` flag, so the endow drops on a weapon swap.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fireweapon,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk_ele],
    flags: [:remove_on_unequip_weapon],
    end_on_start: [
      :sc_aspersio,
      :sc_encpoison,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon,
      :sc_watk_element
    ],
    icon: :propertyfire

  @impl true
  def modifiers(_instance, _context), do: %{attack_element: :fire}
end
