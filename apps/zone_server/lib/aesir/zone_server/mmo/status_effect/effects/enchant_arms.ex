defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnchantArms do
  @moduledoc """
  Weapon Enchant (SC_ENCHANTARMS), the endow the elemental converters and other
  item scripts cast through ITEM_ENCHANTARMS.

  Endows the weapon with the element carried in `val1`. It outranks every other
  endow: while it lasts the attack element is its own even when Flame Launcher,
  Frost Weapon, Lightning Loader, Seismic Weapon or (in renewal) Enchant Poison
  is also active, because those endows do not end it and it ends only Aspersio
  and an earlier Weapon Enchant. It therefore emits its own
  `enchant_arms_element` modifier, which the damage pipeline reads before the
  shared `attack_element` key.

  Both modes: removed when the weapon is unequipped, dispellable, and cleared
  by Hermode.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_enchantarms,
    no_dispel: false,
    no_clear_buff: false,
    overlap_ignore_level: true,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:atk_ele],
    flags: [:remove_on_unequip_weapon],
    end_on_start: [:sc_enchantarms, :sc_aspersio],
    icon: :weaponproperty

  alias Aesir.ZoneServer.Mmo.Element

  @impl true
  def modifiers(instance, _context),
    do: %{enchant_arms_element: Element.from_id!(instance.val1)}
end
