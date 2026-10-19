defmodule Aesir.ZoneServer.Mmo.StatusEffect.MobResistanceSnapshotTest do
  @moduledoc """
  Resistance inputs come from the published calculated snapshot: a buffed
  monster's primary stats and hard MDEF reach `ContextBuilder` through
  `get_stats/1`, not from its form definition.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Stats
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

    MobState.new(1001, mob_data, spawn_ref, "resistance_map", 30, 30)
  end

  defp commit(state, flags) do
    entries = StatusStorage.get_unit_statuses(:mob, state.instance_id)
    %{state | calculated: Stats.recalculate(state, entries, flags)}
  end

  test "ContextBuilder reads the form stats before any recalculation" do
    state = mob_state()
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

    assert ContextBuilder.get_unit_stats(:mob, state.instance_id).str == 40
  end

  test "a buffed primary reaches ContextBuilder only after the owner commit" do
    state = mob_state()
    Registry.register_module(Enum.find(Effects.all(), &(&1.id() == :sc_blessing)))
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

    :ok = Interpreter.apply_status(:mob, state.instance_id, :sc_blessing, val1: 10, val2: 10)

    assert ContextBuilder.get_unit_stats(:mob, state.instance_id).str == 40

    committed = commit(state, ["Str"])
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, committed, self())

    assert ContextBuilder.get_unit_stats(:mob, state.instance_id).str == 50
  end

  test "ContextBuilder reads the calculated hard MDEF" do
    state = mob_state()
    Registry.register_module(Enum.find(Effects.all(), &(&1.id() == :sc_endure)))
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

    :ok =
      Interpreter.apply_status(:mob, state.instance_id, :sc_endure,
        val1: 20,
        val3: 0,
        val4: 0
      )

    committed = commit(state, ["Mdef"])
    assert committed.calculated.mdef == 30
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, committed, self())

    assert ContextBuilder.get_unit_stats(:mob, state.instance_id).mdef == 30
  end
end
