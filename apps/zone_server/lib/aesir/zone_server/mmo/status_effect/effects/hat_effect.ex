defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.HatEffect do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_hat_effect,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    icon: :hat_effect
end
