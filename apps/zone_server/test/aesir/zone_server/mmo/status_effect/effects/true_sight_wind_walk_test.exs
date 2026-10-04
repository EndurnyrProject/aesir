defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TrueSightWindWalkTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.TrueSight
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.WindWalk
  alias Aesir.ZoneServer.Mmo.StatusEntry

  test "True Sight grants all stats plus level-scaled critical, HIT and ATK" do
    assert TrueSight.modifiers(%StatusEntry{type: :sc_truesight, val1: 1}, %{}) ==
             %{str: 5, agi: 5, vit: 5, int: 5, dex: 5, luk: 5, critical: 1, hit: 3, atk_rate: 2}

    assert TrueSight.modifiers(%StatusEntry{type: :sc_truesight, val1: 10}, %{}) ==
             %{
               str: 5,
               agi: 5,
               vit: 5,
               int: 5,
               dex: 5,
               luk: 5,
               critical: 10,
               hit: 30,
               atk_rate: 20
             }
  end

  test "Wind Walker rounds flee up and grants level-scaled haste" do
    for {level, flee, haste} <- [{1, 1, 2}, {2, 1, 4}, {10, 5, 20}] do
      assert WindWalk.modifiers(%StatusEntry{type: :sc_windwalk, val1: level}, %{}) ==
               %{flee: flee, haste_rate: haste}
    end
  end
end
