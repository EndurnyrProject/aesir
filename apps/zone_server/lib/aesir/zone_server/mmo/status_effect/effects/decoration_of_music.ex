defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DecorationOfMusic do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_decoration_of_music,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    icon: :decoration_of_music
end
