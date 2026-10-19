defmodule Aesir.ZoneServer.Unit.Mob.CalculatedReadersTest do
  @moduledoc """
  The published snapshot is the only source a monster's calculated readers may
  use: a cross-process storage write changes nothing until the owning session
  recalculates and commits.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
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

    MobState.new(1001, mob_data, spawn_ref, "calculated_readers_map", 30, 30)
  end

  defp register(state) do
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
    state
  end

  defp commit(state, flags) do
    entries = StatusStorage.get_unit_statuses(:mob, state.instance_id)
    %{state | calculated: Stats.recalculate(state, entries, flags)}
  end

  test "a raw storage write leaves the published snapshot untouched" do
    state = register(mob_state())
    baseline = MobState.to_combatant(state)

    :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_decreaseagi, val1: 5, val2: 5)

    assert MobState.to_combatant(state).base_stats.agi == baseline.base_stats.agi
    assert MobState.get_stats(state).str == state.calculated.str
  end

  test "only the owner recalculation publishes the new values" do
    state = register(mob_state())
    baseline = MobState.to_combatant(state)

    :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_decreaseagi, val1: 5, val2: 5)
    committed = commit(state, ["Agi"])

    assert committed.calculated.agi == baseline.base_stats.agi - 5
    assert MobState.to_combatant(committed).base_stats.agi == baseline.base_stats.agi - 5
    assert MobState.get_stats(committed).agi == baseline.base_stats.agi - 5
  end

  test "to_combatant, get_stats and get_element read the snapshot without storage" do
    state = register(mob_state())
    calculated = state.calculated
    combatant = MobState.to_combatant(state)
    stats = MobState.get_stats(state)

    assert {combatant.base_stats.str, combatant.base_stats.vit, stats.int} ==
             {calculated.str, calculated.vit, calculated.int}

    assert {stats.def, stats.mdef, stats.max_hp, stats.max_sp} ==
             {calculated.def, calculated.mdef, calculated.max_hp, calculated.max_sp}

    assert MobState.get_element(state) == {calculated.def_ele, calculated.ele_lv}
    assert combatant.element == {calculated.def_ele, calculated.ele_lv}
    assert combatant.weapon.element == calculated.attack_element
  end

  test "the calculated combat numbers come from the snapshot bounds and timing" do
    state = register(mob_state())
    calculated = state.calculated
    combatant = MobState.to_combatant(state)

    assert {combatant.combat_stats.atk, combatant.combat_stats.atk_min,
            combatant.combat_stats.atk_max} ==
             {calculated.batk, calculated.watk_min, calculated.watk_max}

    assert {combatant.combat_stats.hit, combatant.combat_stats.flee,
            combatant.combat_stats.perfect_dodge} ==
             {calculated.hit, calculated.flee, calculated.flee2}

    assert {combatant.combat_stats.soft_def, combatant.combat_stats.soft_mdef} ==
             {calculated.def2, calculated.mdef2}

    assert {combatant.max_hp, combatant.max_sp} == {calculated.max_hp, calculated.max_sp}
    assert combatant.attack_delay_ms == calculated.adelay
    assert combatant.amotion == calculated.amotion
  end
end
