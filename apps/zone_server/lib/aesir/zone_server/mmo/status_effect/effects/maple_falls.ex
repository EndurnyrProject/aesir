defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MapleFalls do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_maple_falls,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    icon: :maple_falls
end
