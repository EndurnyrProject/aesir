defmodule Aesir.ZoneServer.Unit.Mob.MobSupervisorKillAllTest do
  @moduledoc """
  `MobSupervisor.kill_all/1` must tolerate a map with no running mob
  supervisor (a later castle-release caller invokes it on maps that may
  never have spawned one), and must still terminate and unregister every
  mob on a map that does have one.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  # Not a real map: `MapManager` boots a `Coordinator` (and its `MobSupervisor`)
  # for every real map shortly after app start, which would race this test's
  # own `start_supervised!` for the same map name.
  @map "test_mob_supervisor_kill_all"

  test "returns :ok for a map with no running mob supervisor" do
    assert MobSupervisor.kill_all("no_such_map") == :ok
  end

  test "terminates every mob on a live supervisor and clears their registry entries" do
    start_supervised!(%{id: MobSupervisor, start: {MobSupervisor, :start_link, [@map]}})

    a = spawn_mob(1)
    b = spawn_mob(2)

    assert MobSupervisor.kill_all(@map) == :ok

    refute Process.alive?(a.pid)
    refute Process.alive?(b.pid)
    assert UnitRegistry.get_unit(:mob, a.unit_id) == {:error, :not_found}
    assert UnitRegistry.get_unit(:mob, b.unit_id) == {:error, :not_found}
  end

  defp spawn_mob(instance_id) do
    mob_state = build_mob_state(instance_id)

    {:ok, pid} = MobSupervisor.spawn_mob(@map, mob_state, awake: false)
    UnitRegistry.register_unit(:mob, instance_id, MobSupervisor, mob_state, pid)

    %{pid: pid, unit_id: instance_id}
  end

  defp build_mob_state(instance_id) do
    %MobState{
      instance_id: instance_id,
      mob_id: 1002,
      mob_data: %MobDefinition{
        id: 1002,
        aegis_name: "PORING",
        name: "Poring",
        level: 3,
        hp: 60,
        sp: 0,
        atk: 7,
        matk: 0,
        def: 0,
        mdef: 5,
        stats: %{str: 1, agi: 1, vit: 1, int: 0, dex: 6, luk: 30},
        attack_range: 1,
        walk_speed: 200,
        attack_delay: 1_000,
        attack_motion: 672,
        client_attack_motion: 500,
        damage_motion: 480,
        element: {:water, 1},
        race: :plant,
        size: :medium
      },
      spawn_ref: nil,
      map_name: @map,
      x: 51,
      y: 50,
      dir: 0,
      hp: 50,
      max_hp: 60,
      sp: 0,
      max_sp: 0,
      spawned_at: System.system_time(:second),
      walk_speed: 200,
      is_dead: false
    }
  end
end
