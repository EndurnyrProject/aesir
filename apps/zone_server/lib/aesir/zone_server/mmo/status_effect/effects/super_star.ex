defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SuperStar do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_super_star,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    icon: :super_star
end
