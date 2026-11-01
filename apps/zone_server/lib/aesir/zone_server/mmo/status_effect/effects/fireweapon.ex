defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fireweapon do
  @moduledoc """
  Flame Launcher (SC_FIREWEAPON).

  Endows the weapon with the fire element, replacing other weapon endows.
  In Renewal, players also gain `val1` percent fire-element magic damage.
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
    id: :sc_fireweapon,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [renewal: [:all], pre_renewal: [:atk_ele]],
    flags: [:remove_on_unequip_weapon],
    end_on_start: [
      :sc_aspersio,
      :sc_encpoison,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon
    ],
    icon: :propertyfire

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(%{val1: level}, %{unit_type: :player}) do
    case GameMode.mode() do
      :renewal -> %{:attack_element => :fire, {:magic_atk_ele, :fire} => level}
      :pre_renewal -> %{attack_element: :fire}
    end
  end

  def modifiers(_instance, _context), do: %{attack_element: :fire}
end
