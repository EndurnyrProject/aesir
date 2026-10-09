defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GangsterParadise do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gangsterparadise,
    icon: nil,
    no_dispel: false,
    no_clear_buff: true,
    engine_only: true,
    no_save: true,
    bypass_resistance: true
end
