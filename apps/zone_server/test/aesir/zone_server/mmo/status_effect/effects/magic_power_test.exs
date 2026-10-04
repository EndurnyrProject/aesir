defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicPowerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicPower

  @target {:player, 1}
  @cold_bolt 14
  @bash 5
  @cast_cancel 275

  @tag game_mode: :renewal
  test "renewal amplifies base plus weapon MATK and survives offensive casts" do
    instance = %{val1: 4, state: %{}}

    assert MagicPower.modifiers(instance, %{}) == %{base_matk_rate: 20}

    assert MagicPower.on_committed_action(@target, instance, {:skill_resolved, @cold_bolt}, %{}) ==
             {:ok, instance}
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal amplifies final MATK and is spent once an offensive spell resolves" do
    instance = %{val1: 4, state: %{}}

    assert MagicPower.modifiers(instance, %{}) == %{matk_rate: 20}

    assert MagicPower.on_committed_action(@target, instance, {:skill_resolved, @cold_bolt}, %{}) ==
             :remove

    for kept <- [
          {:skill, @cold_bolt},
          {:skill_resolved, @bash},
          {:skill_resolved, @cast_cancel},
          :normal_attack
        ] do
      assert MagicPower.on_committed_action(@target, instance, kept, %{}) == {:ok, instance}
    end
  end
end
