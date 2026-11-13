defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FlingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fling

  test "a player loses only soft DEF; any other holder also loses hard DEF" do
    {:ok, player} = Fling.on_apply({:player, 1}, entry(3), %{unit_type: :player})
    {:ok, mob} = Fling.on_apply({:mob, 2}, entry(5), %{unit_type: :mob})

    assert Fling.modifiers(player, %{}) == %{def_rate: 0, def2_rate: -15}
    assert Fling.modifiers(mob, %{}) == %{def_rate: -25, def2_rate: -25}
  end

  test "a restored status keeps its stored values" do
    stored = %{entry(3) | val2: 15, val3: 15}

    assert {:ok, ^stored} =
             Fling.on_apply({:player, 1}, stored, %{loaded: true, unit_type: :player})
  end

  defp entry(coins), do: %{val1: coins, val2: 0, val3: 0, val4: 0}
end
