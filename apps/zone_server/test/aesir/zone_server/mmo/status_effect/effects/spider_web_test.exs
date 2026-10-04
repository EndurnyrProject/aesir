defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWebTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Manager)
    :ok
  end

  @target {:mob, 9_701}

  defp web(gid, expires_at) do
    :ok =
      Storage.insert(%Group{
        group_id: gid,
        skill_id: 405,
        skill_name: :pf_spiderweb,
        level: 1,
        caster_id: 1,
        caster_type: :player,
        map_name: "prontera",
        center: {gid, 100},
        cells: [{gid, 100}],
        next_tick_at: nil,
        expires_at: expires_at,
        interval: 1_000,
        state: %{}
      })
  end

  test "halves the holder's FLEE" do
    assert SpiderWeb.modifiers(%{state: %{groups: [51]}}, %{}) == %{flee_rate: -50}
  end

  test "fire against a webbed unit gains 100 element ratio points" do
    defender = %{unit_type: :mob, unit_id: 9_701, element: {:earth, 1}}

    assert DamageShared.apply_element(100, :fire, defender) ==
             100 * ElementModifiers.get_modifier(:fire, :earth, 1)

    :ok = StatusStorage.apply_status(:mob, 9_701, :sc_spiderweb, state: %{groups: [51]})

    assert DamageShared.apply_element(100, :fire, defender) ==
             100 * ElementModifiers.get_modifier(:fire, :earth, 1, 100)

    assert DamageShared.apply_element(100, :water, defender) ==
             100 * ElementModifiers.get_modifier(:water, :earth, 1)
  end

  test "a fire hit burns the web closest to running out and keeps the hold" do
    web(51, 9_000)
    web(52, 5_000)
    instance = %{state: %{groups: [51, 52]}}
    expect(Manager, :destroy_async, fn 52 -> :ok end)

    assert {:ok, 300, %{state: %{groups: [51]}}} =
             SpiderWeb.absorb_damage(@target, instance, %{element: :fire, damage: 300}, %{})
  end

  test "a fire hit on the last web ends the hold" do
    web(51, 9_000)

    assert SpiderWeb.absorb_damage(
             @target,
             %{state: %{groups: [51]}},
             %{element: :fire, damage: 300},
             %{}
           ) ==
             {:remove, 300}
  end

  test "other elements pass through" do
    instance = %{state: %{groups: [51]}}

    assert SpiderWeb.absorb_damage(@target, instance, %{element: :water, damage: 300}, %{}) ==
             {:ok, 300, instance}
  end

  test "ending the hold tears down every web" do
    test_pid = self()
    stub(Manager, :destroy_async, fn gid -> send(test_pid, {:destroyed, gid}) end)

    assert SpiderWeb.on_expire(@target, %{state: %{groups: [51, 52]}}, %{}) == :ok
    assert_received {:destroyed, 51}
    assert_received {:destroyed, 52}
  end
end
