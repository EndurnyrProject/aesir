defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Tarotcard do
  @moduledoc """
  Renewal Sun-card marker granting immunity to further Tarot cards.

  It carries no stat modifiers and is kept across a logout. Pre-renewal Tarot never
  applies this marker, so drawing further cards remains possible there.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_tarotcard,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff],
    icon: :tarotcard
end
