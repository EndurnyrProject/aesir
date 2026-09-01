defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Summer do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_summer,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    option: :summer
end
