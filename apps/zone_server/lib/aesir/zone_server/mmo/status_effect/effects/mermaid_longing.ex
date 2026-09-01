defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MermaidLonging do
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mermaid_longing,
    target_types: [:player],
    permanent: true,
    no_save: true,
    no_dispel: true,
    remove_on_death: false,
    icon: :mermaid_longing
end
