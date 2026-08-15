defmodule Aesir.ZoneServer.Integration.MobSupervisorKillTest do
  @moduledoc """
  `MobSupervisor.kill_by_event/2` — the removal path behind the `killmonster`
  NPC buildin. Matching mobs are terminated and unregistered without firing
  their death event or scheduling a respawn; non-matching mobs are spared.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor

  # Not a real map: `MapManager` boots a `Coordinator` (and its `MobSupervisor`)
  # for every real map shortly after app start, which would race this test's
  # own `start_supervised!` for the same map name.
  @map "test_mob_supervisor_kill"

  setup do
    start_supervised!(%{id: MobSupervisor, start: {MobSupervisor, :start_link, [@map]}})
    :ok
  end

  test "kills mobs tagged with the given owner event, sparing others" do
    a = spawn_mob(owner_event: "E::OnA", respawn_time: 0)
    b = spawn_mob(owner_event: "E::OnB", respawn_time: 0)

    MobSupervisor.kill_by_event(@map, "E::OnA")

    refute Process.alive?(a.pid)
    assert Process.alive?(b.pid)
    assert UnitRegistry.get_unit(:mob, a.unit_id) == {:error, :not_found}
    assert match?({:ok, _}, UnitRegistry.get_unit(:mob, b.unit_id))
  end

  test ":all kills script-summoned mobs (respawn_time 0), sparing spawn-table mobs" do
    summoned = spawn_mob(owner_event: nil, respawn_time: 0)
    permanent = spawn_mob(owner_event: nil, respawn_time: 5_000)

    MobSupervisor.kill_by_event(@map, :all)

    refute Process.alive?(summoned.pid)
    assert Process.alive?(permanent.pid)
    assert UnitRegistry.get_unit(:mob, summoned.unit_id) == {:error, :not_found}
  end

  test "kill_all kills spawn-table and summoned mobs alike, without respawn" do
    summoned = spawn_mob(owner_event: "E::OnA", respawn_time: 0)
    permanent = spawn_mob(owner_event: nil, respawn_time: 5_000)

    MobSupervisor.kill_all(@map)

    refute Process.alive?(summoned.pid)
    refute Process.alive?(permanent.pid)
    assert UnitRegistry.get_unit(:mob, summoned.unit_id) == {:error, :not_found}
    assert UnitRegistry.get_unit(:mob, permanent.unit_id) == {:error, :not_found}
  end

  test "a non-matching event label kills nothing" do
    a = spawn_mob(owner_event: "E::OnA", respawn_time: 0)

    MobSupervisor.kill_by_event(@map, "E::OnMissing")

    assert Process.alive?(a.pid)
  end

  test "count_by_event counts living mobs by owner event, and :all counts every mob" do
    spawn_mob(owner_event: "E::OnA", respawn_time: 0)
    spawn_mob(owner_event: "E::OnA", respawn_time: 0)
    spawn_mob(owner_event: "E::OnB", respawn_time: 5_000)

    assert MobSupervisor.count_by_event(@map, "E::OnA") == 2
    assert MobSupervisor.count_by_event(@map, "E::OnB") == 1
    assert MobSupervisor.count_by_event(@map, "E::OnMissing") == 0
    assert MobSupervisor.count_by_event(@map, :all) == 3
  end

  test "count_by_event counts 0 on a map without a running mob supervisor" do
    assert MobSupervisor.count_by_event("no_such_map_running", :all) == 0
  end

  defp spawn_mob(opts) do
    unit_id = System.unique_integer([:positive])
    mob_state = build_mob_state(unit_id, opts)

    {:ok, pid} = MobSupervisor.spawn_mob(@map, mob_state, awake: false)
    UnitRegistry.register_unit(:mob, unit_id, MobSession, mob_state, pid)
    SpatialIndex.add_unit(:mob, unit_id, mob_state.x, mob_state.y, @map)

    %{pid: pid, unit_id: unit_id}
  end

  defp build_mob_state(unit_id, opts) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 1,
      base_exp: 10,
      job_exp: 5,
      drops: [],
      hp: 100,
      sp: 0,
      stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
      atk: 10,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: Keyword.fetch!(opts, :respawn_time),
      spawn_area: %MobSpawn.SpawnArea{x: 150, y: 150}
    }

    unit_id
    |> MobState.new(mob_data, spawn_ref, @map, 150, 150)
    |> MobState.set_owner_event(Keyword.get(opts, :owner_event))
  end
end
