defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WhistleTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  @tag game_mode: :renewal
  test "renewal Whistle excludes other songs and persists" do
    definition = Registry.get_definition(:sc_whistle)
    assert definition.end_on_start == [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun]
    refute definition.no_save
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal Whistle coexists with other songs and is not saved" do
    definition = Registry.get_definition(:sc_whistle)
    assert definition.end_on_start == []
    assert definition.no_save
  end
end
