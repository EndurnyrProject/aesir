defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Tarotcard do
  @moduledoc """
  Renewal Sun-card marker granting immunity to further Tarot cards.

  It carries no stat modifiers and is not saved. Pre-renewal Tarot never
  applies this marker, so drawing further cards remains possible there.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_tarotcard,
    no_dispel: false,
    properties: [:debuff],
    no_save: true,
    icon: :tarotcard
end
