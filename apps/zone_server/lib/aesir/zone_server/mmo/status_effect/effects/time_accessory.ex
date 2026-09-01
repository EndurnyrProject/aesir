defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TimeAccessory do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_time_accessory,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    icon: :time_accessory
end
