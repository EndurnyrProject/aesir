defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StrangeLights do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_strangelights,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    icon: :strangelights
end
