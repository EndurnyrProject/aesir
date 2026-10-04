defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicPowerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicPower
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @target {:player, 1}
  @cold_bolt 14
  @bash 5
  @cast_cancel 275

  defp fresh, do: %StatusEntry{type: :sc_magicpower, val1: 4, state: %{}}

  @tag game_mode: :renewal
  test "renewal amplifies base plus weapon MATK at once and ignores casts" do
    assert MagicPower.modifiers(fresh(), %{}) == %{base_matk_rate: 20}

    assert MagicPower.on_committed_action(@target, fresh(), {:skill, @cold_bolt}, %{}) ==
             {:ok, fresh()}
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal arms at the next offensive spell's cast start and ends at the one after" do
    assert MagicPower.modifiers(fresh(), %{}) == %{}

    assert {:ok, armed} =
             MagicPower.on_committed_action(@target, fresh(), {:skill, @cold_bolt}, %{})

    assert MagicPower.modifiers(armed, %{}) == %{base_matk_rate: 20}

    assert MagicPower.on_committed_action(@target, armed, {:skill, @cold_bolt}, %{}) == :remove
  end

  @tag game_mode: :pre_renewal
  test "weapon, no-damage casts and normal attacks neither arm nor end it" do
    for action <- [{:skill, @bash}, {:skill, @cast_cancel}, :normal_attack] do
      assert MagicPower.on_committed_action(@target, fresh(), action, %{}) == {:ok, fresh()}
    end
  end
end
