defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fstone do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fstone,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    icon: :fstone
end
