defmodule Aesir.ZoneServer.Map.CoordinatorActivityTest do
  @moduledoc """
  Verifies player-presence-driven mob activity: lazy initial spawn on the first
  player, dormancy after the map stays empty past the grace period, and wake on
  player return. Mob spawn counts come from real spawn configs against real mob
  data (Poring), with the supervisor layer stubbed.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map_name "coordinator_activity_test_map"
  @poring_id 1002

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    :ets.insert(
      EtsTable.table_for(:map_cache),
      {@map_name, MapData.new(@map_name, 200, 200)}
    )

    test_pid = self()

    stub(MobSupervisor, :spawn_mob, fn _map, %MobState{} = mob_state, opts ->
      send(test_pid, {:spawned, mob_state, Keyword.fetch!(opts, :awake)})
      {:ok, spawn(fn -> :ok end)}
    end)

    stub(MobSupervisor, :wake_all_mobs, fn _map ->
      send(test_pid, :woke_all)
      :ok
    end)

    stub(MobSupervisor, :sleep_all_mobs, fn _map ->
      send(test_pid, :slept_all)
      :ok
    end)

    :ok
  end

  defp base_state(overrides) do
    struct!(
      %Coordinator{
        map_name: @map_name,
        spawn_data: [spawn_config()],
        map_data: MapData.new(@map_name, 200, 200),
        respawn_timers: %{},
        next_mob_id: 1,
        recently_stopped: %{}
      },
      overrides
    )
  end

  defp spawn_config do
    %MobSpawn{
      mob: @poring_id,
      amount: 2,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 3, ys: 3}
    }
  end

  defp tick(state), do: Coordinator.handle_info(:broadcast_tick, state)

  defp register_player(action_state, hp) do
    player = %PlayerState{
      character_id: 1001,
      map_name: @map_name,
      x: 100,
      y: 100,
      action_state: action_state,
      stats: %{current_state: %{hp: hp}}
    }

    SpatialIndex.add_player(player.character_id, player.x, player.y, player.map_name)
    UnitRegistry.register_unit(:player, player.character_id, PlayerState, player, self())
  end

  describe "lazy initial spawn" do
    test "the first tick with a player on the map spawns all mobs awake" do
      register_player(:idle, 100)

      {:noreply, new_state} = tick(base_state([]))

      assert new_state.mobs_spawned
      assert new_state.mobs_awake
      assert_received {:spawned, _, true}
      assert_received {:spawned, _, true}
    end

    test "ticks on a never-visited empty map spawn nothing" do
      {:noreply, new_state} = tick(base_state([]))

      refute new_state.mobs_spawned
      refute new_state.mobs_awake
      refute_received {:spawned, _, _}
    end

    test "a connected corpse does not activate an unvisited map" do
      register_player(:dead, 0)

      {:noreply, new_state} = tick(base_state([]))

      refute new_state.mobs_spawned
      refute new_state.mobs_awake
      refute_received {:spawned, _, _}
    end
  end

  describe "dormancy" do
    test "a map empty past the grace period puts its mobs to sleep" do
      long_ago = System.monotonic_time(:millisecond) - Coordinator.mob_sleep_grace() - 1

      {:noreply, new_state} =
        tick(base_state(mobs_spawned: true, mobs_awake: true, empty_since: long_ago))

      refute new_state.mobs_awake
      assert_received :slept_all
    end

    test "a map empty within the grace period keeps its mobs awake" do
      {:noreply, new_state} = tick(base_state(mobs_spawned: true, mobs_awake: true))

      assert new_state.mobs_awake
      assert new_state.empty_since
      refute_received :slept_all
    end

    test "a player returning to a dormant map wakes its mobs" do
      register_player(:idle, 100)

      {:noreply, new_state} =
        tick(base_state(mobs_spawned: true, mobs_awake: false, empty_since: 0))

      assert new_state.mobs_awake
      assert new_state.empty_since == nil
      assert_received :woke_all
    end

    test "a connected corpse does not wake a dormant map" do
      register_player(:dead, 0)

      {:noreply, new_state} =
        tick(base_state(mobs_spawned: true, mobs_awake: false, empty_since: 0))

      refute new_state.mobs_awake
      refute_received :woke_all
    end

    test "a respawn on a dormant map starts the mob asleep" do
      state = base_state(mobs_spawned: true, mobs_awake: false)

      {:noreply, _new_state} = Coordinator.handle_info({:respawn_mob, spawn_config()}, state)

      assert_received {:spawned, _, false}
    end
  end

  describe "spawn position" do
    test "an all-zero spawn area lands on a random walkable cell of the map" do
      # rAthena semantics: x/y = 0,0 means anywhere on the map. Cell (0, 0) is a
      # wall here, so a literal placement would be rejected.
      map_data =
        @map_name
        |> MapData.new(200, 200)
        |> MapData.set_cell(0, 0, GatType.wall())

      config = %MobSpawn{
        mob: @poring_id,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: 0, y: 0, xs: 0, ys: 0}
      }

      state = base_state(map_data: map_data, mobs_spawned: true, mobs_awake: true)
      :ets.insert(EtsTable.table_for(:map_cache), {@map_name, map_data})

      {:noreply, _new_state} = Coordinator.handle_info({:respawn_mob, config}, state)

      assert_received {:spawned, %MobState{x: x, y: y}, true}
      assert {x, y} != {0, 0}
      assert x in 0..199
      assert y in 0..199
    end

    test "an area spawn stays within its bounds" do
      state = base_state(map_data: MapData.new(@map_name, 200, 200))
      register_player(:idle, 100)

      {:noreply, _new_state} = tick(state)

      assert_received {:spawned, %MobState{x: x, y: y}, true}
      assert x in 97..103
      assert y in 97..103
    end

    test "a fixed spawn point is used as-is" do
      config = %MobSpawn{
        mob: @poring_id,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: 42, y: 43, xs: 0, ys: 0}
      }

      state = base_state(mobs_spawned: true, mobs_awake: true)

      {:noreply, _new_state} = Coordinator.handle_info({:respawn_mob, config}, state)

      assert_received {:spawned, %MobState{x: 42, y: 43}, true}
    end
  end

  describe "spawn retry when the target cell is blocked" do
    setup do
      prev = Application.get_env(:zone_server, :spawn_retry_delay_ms)
      Application.put_env(:zone_server, :spawn_retry_delay_ms, 10)

      on_exit(fn ->
        case prev do
          nil -> Application.delete_env(:zone_server, :spawn_retry_delay_ms)
          value -> Application.put_env(:zone_server, :spawn_retry_delay_ms, value)
        end
      end)

      config = %MobSpawn{
        mob: @poring_id,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: 42, y: 43, xs: 0, ys: 0}
      }

      %{config: config}
    end

    test "reschedules the respawn instead of losing the mob", %{config: config} do
      reject(&MobSupervisor.spawn_mob/3)
      :ok = Cell.put(@map_name, 42, 43, :test_blocker, 1, blocks_movement: true)

      state = base_state(mobs_spawned: true, mobs_awake: true)

      {:noreply, new_state} = Coordinator.handle_info({:respawn_mob, config}, state)

      refute_received {:spawned, _, _}
      assert new_state == state
      assert_receive {:respawn_mob, ^config}, 200
    end

    test "a later retry with the cell free spawns the mob", %{config: config} do
      :ok = Cell.put(@map_name, 42, 43, :test_blocker, 1, blocks_movement: true)

      state = base_state(mobs_spawned: true, mobs_awake: true)
      {:noreply, _state} = Coordinator.handle_info({:respawn_mob, config}, state)

      refute_received {:spawned, _, _}

      Cell.delete(@map_name, 42, 43, :test_blocker, 1)
      assert_receive {:respawn_mob, ^config}, 200

      {:noreply, _state} = Coordinator.handle_info({:respawn_mob, config}, state)

      assert_received {:spawned, %MobState{x: 42, y: 43}, true}
    end
  end
end
