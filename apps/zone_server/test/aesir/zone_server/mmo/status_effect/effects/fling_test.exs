defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FlingTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fling

  test "a player loses only soft DEF; any other holder also loses hard DEF" do
    {:ok, player} = Fling.on_apply({:player, 1}, entry(3), %{unit_type: :player})
    {:ok, mob} = Fling.on_apply({:mob, 2}, entry(5), %{unit_type: :mob})

    assert Fling.modifiers(player, %{}) == %{def_rate: 0, def2_rate: -15}
    assert Fling.modifiers(mob, %{}) == %{def_rate: -25, def2_rate: -25}
  end

  test "the holder's DEF falls by the rate's share, not the rate's product" do
    {:ok, player} = Fling.on_apply({:player, 1}, entry(3), %{unit_type: :player})
    {:ok, mob} = Fling.on_apply({:mob, 2}, entry(5), %{unit_type: :mob})

    assert defense(player) == {101, 86}
    assert defense(mob) == {76, 76}
  end

  test "a restored status keeps its stored values" do
    stored = %{entry(3) | val2: 15, val3: 15}

    assert {:ok, ^stored} =
             Fling.on_apply({:player, 1}, stored, %{loaded: true, unit_type: :player})
  end

  defp entry(coins), do: %{val1: coins, val2: 0, val3: 0, val4: 0}

  # A 101/101 DEF holder, run through the same defense reader the damage
  # calculator uses, so the assertion is the DEF the game applies.
  defp defense(instance) do
    hole = build(:mob_combatant, def: 101, soft_def: 101)

    DamageInputs.physical_defense(
      hole,
      nil,
      :apply_status_def,
      :omit_equipment_def_ignore,
      Fling.modifiers(instance, %{})
    )
  end
end
