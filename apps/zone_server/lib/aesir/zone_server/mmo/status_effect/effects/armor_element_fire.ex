defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ArmorElementFire do
  @moduledoc """
  Fireproof Potion's elemental resistances, identical in both game modes.

  `val1` through `val4` are signed Water, Earth, Fire and Wind resistance
  percentages. Other resistance potions coexist; reapplication replaces this
  status and refreshes its duration. Dispel does not remove it.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_armor_element_fire,
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: false,
    overlap_ignore_level: true,
    properties: [:buff],
    calc_flags: [:subele_water, :subele_earth, :subele_fire, :subele_wind],
    icon: :resist_property_fire

  @impl true
  def modifiers(instance, _context) do
    %{
      subele_water: instance.val1,
      subele_earth: instance.val2,
      subele_fire: instance.val3,
      subele_wind: instance.val4
    }
  end
end
