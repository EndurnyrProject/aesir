defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ArmorResist do
  @moduledoc """
  Undead Elemental Scroll grants Water, Earth, Fire and Wind resistance from its four values.
  Identical in both modes. Reapplication refreshes any level; removing armor,
  death, Dispel or buff clearing ends it. It does not change the defense element.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_armor_resist,
    target_types: [:player],
    no_dispel: false,
    no_clear_buff: false,
    overlap_ignore_level: true,
    flags: [:remove_on_unequip_armor],
    properties: [:buff],
    calc_flags: [:subele_water, :subele_earth, :subele_fire, :subele_wind],
    icon: nil

  @impl true
  def modifiers(instance, _context),
    do: %{
      subele_water: instance.val1,
      subele_earth: instance.val2,
      subele_fire: instance.val3,
      subele_wind: instance.val4
    }
end
