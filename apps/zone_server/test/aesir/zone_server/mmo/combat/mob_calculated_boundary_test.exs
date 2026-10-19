defmodule Aesir.ZoneServer.Mmo.Combat.MobCalculatedBoundaryTest do
  @moduledoc """
  A monster's live battle view exposes only the matrix-classified live
  contributions. Cached snapshot inputs (primaries, HIT/FLEE, defenses, MATK
  rate, ordinary endow elements) must not reappear through a live fold, while
  Provoke's attack percentage and Enchant Arms' weapon element stay live.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp mob_state do
    mob_data =
      struct!(MobDefinition, %{
        id: 1001,
        aegis_name: "test_mob",
        name: "Test Mob",
        level: 25,
        hp: 1000,
        sp: 0,
        stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
        atk: 50,
        atk2: 70,
        matk: 60,
        def: 25,
        mdef: 10,
        attack_range: 1,
        walk_speed: 200,
        attack_delay: 1_200,
        attack_motion: 500,
        client_attack_motion: 400,
        damage_motion: 300,
        element: {:neutral, 1},
        race: :formless,
        size: :medium
      })

    spawn_ref =
      struct!(MobSpawn, %{
        mob: 1001,
        amount: 1,
        respawn_time: 5000,
        spawn_area: struct!(SpawnArea, %{x: 30, y: 30})
      })

    state = MobState.new(1001, mob_data, spawn_ref, "boundary_map", 30, 30)
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
    state
  end

  defp register!(id) do
    Registry.register_module(Enum.find(Effects.all(), &(&1.id() == id)))
  end

  test "Provoke keeps only its live attack percentage" do
    state = mob_state()
    register!(:sc_provoke)

    :ok =
      StatusStorage.apply_status(:mob, state.instance_id, :sc_provoke,
        val1: 10,
        val2: 30,
        val3: 20
      )

    battle = ModifierCalculator.get_battle_modifiers(:mob, state.instance_id)

    assert battle[:atk_rate] == 30
    refute Map.has_key?(battle, :def_rate)
    refute Map.has_key?(battle, :def2_rate)
    refute Map.has_key?(battle, :hit)
    refute Map.has_key?(battle, :batk)
    refute Map.has_key?(battle, :watk)
  end

  test "a cached primary blessing never reappears in the battle view" do
    state = mob_state()
    register!(:sc_blessing)

    :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_blessing, val1: 10, val2: 10)

    battle = ModifierCalculator.get_battle_modifiers(:mob, state.instance_id)

    refute Map.has_key?(battle, :str)
    refute Map.has_key?(battle, :int)
    refute Map.has_key?(battle, :dex)
    refute Map.has_key?(battle, :hit)
  end

  test "Enchant Arms keeps its explicit weapon element, an ordinary endow does not" do
    state = mob_state()
    register!(:sc_enchantarms)
    register!(:sc_aspersio)

    :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_enchantarms, val1: 1)
    :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_aspersio, val1: 1)

    battle = ModifierCalculator.get_battle_modifiers(:mob, state.instance_id)

    assert Map.has_key?(battle, :enchant_arms_element)
    refute Map.has_key?(battle, :attack_element)
  end

  test "a cached Magic Power rate never reappears in the battle view" do
    state = mob_state()
    register!(:sc_magicpower)

    :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_magicpower, val1: 10, val3: 50)

    battle = ModifierCalculator.get_battle_modifiers(:mob, state.instance_id)

    refute Map.has_key?(battle, :base_matk_rate)
    refute Map.has_key?(battle, :matk_rate)
    refute Map.has_key?(battle, :matk)
  end

  test "a field's element ratio stays live" do
    state = mob_state()
    register!(:sc_volcano)

    :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_volcano, val1: 5)

    battle = ModifierCalculator.get_battle_modifiers(:mob, state.instance_id)

    assert Map.has_key?(battle, {:element_ratio, :fire})
    refute Map.has_key?(battle, :batk)
    refute Map.has_key?(battle, :matk)
  end
end
