defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MoonStar do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_moonstar,
    target_types: [:player],
    no_save: true,
    no_dispel: true,
    no_clear_buff: true,
    remove_on_death: false,
    icon: :moonstar
end
