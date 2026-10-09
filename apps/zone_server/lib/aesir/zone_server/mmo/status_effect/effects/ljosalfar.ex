defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Ljosalfar do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_ljosalfar,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    no_clear_buff: true,
    remove_on_death: false,
    icon: :ljosalfar
end
