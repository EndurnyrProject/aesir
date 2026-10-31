defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.HpSpPotionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyDrinkResearch
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.PromoteHealthResearch
  alias Aesir.ZoneServer.Mmo.StatusEntry

  test "potion sizes compute the fixed HP and item-stage SP bonuses with integer rounding" do
    for {level, size, hp, sp} <- [
          {1, 1, 503, 0},
          {3, 1, 510, 0},
          {99, 1, 830, 4},
          {99, 2, 1_830, 9},
          {99, 3, 2_830, 14}
        ] do
      instance = %StatusEntry{val1: 1, val2: size}
      context = %{loaded: false, target: %{base_level: level}, caster: %{base_level: 200}}
      assert {:ok, %{val3: ^hp}} = PromoteHealthResearch.on_apply({:player, 1}, instance, context)
      assert {:ok, %{val3: ^sp}} = EnergyDrinkResearch.on_apply({:player, 1}, instance, context)
    end
  end

  test "thrown potion values use the source level and restoration retains the saved bonus" do
    instance = %StatusEntry{val1: 2, val2: 3, val3: 777}
    context = %{loaded: false, target: %{base_level: 1}, caster: %{base_level: 99}}
    assert {:ok, %{val3: 2_830}} = PromoteHealthResearch.on_apply({:mob, 1}, instance, context)
    assert {:ok, %{val3: 14}} = EnergyDrinkResearch.on_apply({:mob, 1}, instance, context)

    for effect <- [PromoteHealthResearch, EnergyDrinkResearch] do
      assert {:ok, ^instance} = effect.on_apply({:player, 1}, instance, %{context | loaded: true})
    end

    assert PromoteHealthResearch.modifiers(instance, %{unit_type: :mob}) == %{max_hp: 777}
    assert EnergyDrinkResearch.modifiers(instance, %{unit_type: :mob}) == %{}

    assert EnergyDrinkResearch.modifiers(instance, %{unit_type: :player}) == %{
             max_sp_item_rate: 777
           }
  end
end
