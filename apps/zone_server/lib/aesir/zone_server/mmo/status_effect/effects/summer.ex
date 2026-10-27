defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Summer do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_summer,
    properties: [:prevents_attack],
    flags: [:stop_attacking],
    target_types: [:player],
    no_dispel: true,
    no_clear_buff: true,
    remove_on_death: false,
    option: :summer
end
