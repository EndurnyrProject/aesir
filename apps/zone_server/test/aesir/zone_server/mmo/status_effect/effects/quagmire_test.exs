defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.QuagmireTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Quagmire
  alias Aesir.ZoneServer.Mmo.StatusEntry

  # rAthena src/map/status.cpp:6816-6863, 7039-7059, and 11443-11445.
  test "applies exact player and mob modifiers at levels 1 through 5" do
    for level <- 1..5 do
      player = %StatusEntry{type: :sc_quagmire, val1: level, val2: 5 * level, state: %{}}
      mob = %StatusEntry{type: :sc_quagmire, val1: level, val2: 10 * level, state: %{}}

      assert Quagmire.modifiers(player, %{}) == %{
               agi: -5 * level,
               dex: -5 * level,
               aspd: 5 * level,
               movement_speed: 50
             }

      assert Quagmire.modifiers(mob, %{}) == %{
               agi: -10 * level,
               dex: -10 * level,
               aspd: 10 * level,
               movement_speed: 50
             }
    end
  end
end
