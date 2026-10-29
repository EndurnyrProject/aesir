defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ParryingTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Parrying
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpecialEffect
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @cart_termination 485

  test "a successful weapon roll stops the hit and plays the guard effect" do
    expect(SpecialEffect, :play, fn {:player, 3}, :guard, :area -> :ok end)
    :rand.seed(:exsss, {2, 3, 4})

    assert {:ok, 0, _entry} =
             Parrying.absorb_damage({:player, 3}, %StatusEntry{val1: 1}, weapon_hit(40), %{})
  end

  test "a parry arms the holder's own attack delay in its session" do
    stub(SpecialEffect, :play, fn _unit, _effect, _area -> :ok end)
    holder = %PlayerState{character_id: 9_301, action_state: :idle}
    UnitRegistry.register_unit(:player, 9_301, PlayerState, holder, self())
    :rand.seed(:exsss, {2, 3, 4})

    assert {:ok, 0, _entry} =
             Parrying.absorb_damage({:player, 9_301}, %StatusEntry{val1: 1}, weapon_hit(40), %{})

    assert_received {:"$gen_cast", {:combat, :parry}}
  end

  test "a failed roll lets the hit through" do
    reject(&SpecialEffect.play/3)
    :rand.seed(:exsss, {10, 11, 12})

    assert {:ok, 40, _entry} =
             Parrying.absorb_damage({:player, 3}, %StatusEntry{val1: 10}, weapon_hit(40), %{})
  end

  test "level ten blocks a roll of exactly 50 percent" do
    expect(SpecialEffect, :play, fn {:player, 3}, :guard, :area -> :ok end)
    :rand.seed(:exsss, {14, 15, 16})

    assert {:ok, 0, _entry} =
             Parrying.absorb_damage({:player, 3}, %StatusEntry{val1: 10}, weapon_hit(40), %{})
  end

  test "magic and misc hits pass through without a roll" do
    reject(&SpecialEffect.play/3)

    for dmg_type <- [:magic, :misc] do
      :rand.seed(:exsss, {2, 3, 4})
      hit = %{weapon_hit(40) | dmg_type: dmg_type}

      assert {:ok, 40, _entry} =
               Parrying.absorb_damage({:player, 3}, %StatusEntry{val1: 10}, hit, %{})
    end
  end

  test "Cart Termination is never parried" do
    reject(&SpecialEffect.play/3)
    :rand.seed(:exsss, {2, 3, 4})
    hit = weapon_hit(40, @cart_termination)

    assert {:ok, 40, _entry} =
             Parrying.absorb_damage({:player, 3}, %StatusEntry{val1: 10}, hit, %{})
  end

  test "ignore-auto-guard skills are still parried" do
    expect(SpecialEffect, :play, fn {:player, 3}, :guard, :area -> :ok end)
    :rand.seed(:exsss, {2, 3, 4})
    hit = weapon_hit(40, 1004)

    assert {:ok, 0, _entry} =
             Parrying.absorb_damage({:player, 3}, %StatusEntry{val1: 1}, hit, %{})
  end

  test "the status is the last blocker of the damage stage, after Guard" do
    assert :sc_parrying in Registry.statuses_implementing(:absorb_damage)

    stages = Interpreter.absorb_stages()
    assert List.last(stages) == :sc_parrying
    assert Enum.at(stages, -2) == :sc_autoguard
  end

  defp weapon_hit(damage, skill_id \\ nil),
    do: %{damage: damage, dmg_type: :physical, is_short: true, skill_id: skill_id}
end
