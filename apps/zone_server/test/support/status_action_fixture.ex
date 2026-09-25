defmodule Aesir.StatusActionFixture do
  @moduledoc false

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_test_restricted_actions,
    no_dispel: false,
    properties: [:prevents_items, :prevents_chat, :prevents_equip_change]
end
