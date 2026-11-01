defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Waterweapon do
  @moduledoc """
  Frost Weapon (SC_WATERWEAPON).

  Endows the weapon with the water element, replacing other weapon endows.
  In Renewal, players also gain `val1` percent water-element magic damage.
  Pre-renewal and non-player endows only change the weapon element.

  These endows contribute the same `attack_element` modifier and aggregation
  sums colliding keys, so they list each other in `end_on_start`
  (replace-on-cast) to keep two of them from ever being live at once. Weapon
  Enchant (SC_ENCHANTARMS) is not among them: it coexists with this endow and
  outranks it.

  The status ends when the endowed weapon is unequipped, enforced by the
  `:remove_on_unequip_weapon` flag, so the endow drops on a weapon swap.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_waterweapon,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [renewal: [:all], pre_renewal: [:atk_ele]],
    flags: [:remove_on_unequip_weapon],
    end_on_start: [
      :sc_aspersio,
      :sc_encpoison,
      :sc_fireweapon,
      :sc_windweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon
    ],
    icon: :propertywater

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(%{val1: level}, %{unit_type: :player}) do
    case GameMode.mode() do
      :renewal -> %{:attack_element => :water, {:magic_atk_ele, :water} => level}
      :pre_renewal -> %{attack_element: :water}
    end
  end

  def modifiers(_instance, _context), do: %{attack_element: :water}
end
