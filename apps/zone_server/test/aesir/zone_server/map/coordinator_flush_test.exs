defmodule Aesir.ZoneServer.Map.CoordinatorFlushTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Net.Snapshot, as: NetSnapshot
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map_name "prontera"

  setup :setup_ets_tables

  defp register_player(attrs) do
    base = %PlayerState{
      character_id: 1001,
      account_id: 2001,
      map_name: @map_name,
      x: 50,
      y: 50,
      dir: 3,
      movement_state: :standing,
      view_range: 14,
      stats: %{
        current_state: %{hp: 100},
        derived_stats: %{max_hp: 100}
      }
    }

    state = Map.merge(base, Map.new(attrs))

    SpatialIndex.add_unit(:player, state.character_id, state.x, state.y, state.map_name)
    UnitRegistry.register_unit(:player, state.character_id, PlayerState, state, self())
    state
  end

  defp register_mob(attrs) do
    base = %{
      instance_id: 5001,
      map_name: @map_name,
      x: 52,
      y: 50,
      dir: 1,
      movement_state: :moving,
      hp: 1000,
      max_hp: 1000
    }

    mob = base |> Map.merge(Map.new(attrs)) |> then(&struct(MobState, &1))
    SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)
    UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, nil)
    mob
  end

  describe "flush_snapshots/3" do
    test "delivers exactly the dirty entities in AoI; an idle unit is absent" do
      observer = register_player(character_id: 1001, x: 50, y: 50)
      register_mob(instance_id: 5001, x: 52, y: 50, movement_state: :moving)
      register_mob(instance_id: 5002, x: 53, y: 50, movement_state: :moving)
      # idle mob in AoI but never marked dirty
      register_mob(instance_id: 5003, x: 54, y: 50, movement_state: :standing)

      Movement.mark_dirty(@map_name, :mob, 5001, 1)
      Movement.mark_dirty(@map_name, :mob, 5002, 1)

      {deliveries, _recently_stopped} = Coordinator.flush_snapshots(@map_name, %{}, 123)

      pid = self()
      assert [{^pid, chunks}] = deliveries
      ids = chunks |> Enum.flat_map(& &1.entities) |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == [5001, 5002]
      assert observer.character_id == 1001
    end

    test "excludes a dirty unit outside the observer's view_range" do
      register_player(character_id: 1001, x: 50, y: 50, view_range: 14)
      # 30 cells away on a fresh cell, dirty but out of range
      register_mob(instance_id: 5001, x: 90, y: 50, movement_state: :moving)
      Movement.mark_dirty(@map_name, :mob, 5001, 1)

      {deliveries, _} = Coordinator.flush_snapshots(@map_name, %{}, 1)

      assert deliveries == []
    end

    test "never includes the observer's own entity in its delta snapshot" do
      register_player(character_id: 1001, x: 50, y: 50)
      register_mob(instance_id: 5001, x: 52, y: 50, movement_state: :moving)

      # both the player and a mob are dirty
      Movement.mark_dirty(@map_name, :player, 1001, 1)
      Movement.mark_dirty(@map_name, :mob, 5001, 1)

      {deliveries, _} = Coordinator.flush_snapshots(@map_name, %{}, 1)

      pid = self()
      assert [{^pid, chunks}] = deliveries
      ids = chunks |> Enum.flat_map(& &1.entities) |> Enum.map(& &1.id)
      assert 1001 not in ids
      assert ids == [5001]
    end

    test "re-includes a standing unit for K flushes, then drops it" do
      register_player(character_id: 1001, x: 50, y: 50)
      register_mob(instance_id: 5001, x: 52, y: 50, movement_state: :standing)

      # first flush: drained as STANDING (move_state 0)
      Movement.mark_dirty(@map_name, :mob, 5001, 0)
      {d1, rs1} = Coordinator.flush_snapshots(@map_name, %{}, 1)
      assert delivered_ids(d1) == [5001]

      # subsequent flushes with an empty dirty set: echoed K-1 more times
      {d2, rs2} = Coordinator.flush_snapshots(@map_name, rs1, 2)
      assert delivered_ids(d2) == [5001]

      {d3, rs3} = Coordinator.flush_snapshots(@map_name, rs2, 3)
      assert delivered_ids(d3) == [5001]

      # K = 3 echoes total (flushes 1-3), then it drops out on flush 4
      {d4, rs4} = Coordinator.flush_snapshots(@map_name, rs3, 4)
      assert delivered_ids(d4) == []
      assert rs1 != %{}
      assert Map.has_key?(rs3, {:mob, 5001})
      refute Map.has_key?(rs4, {:mob, 5001})
    end

    test "a unit that moves again is removed from recently_stopped" do
      register_player(character_id: 1001, x: 50, y: 50)
      register_mob(instance_id: 5001, x: 52, y: 50, movement_state: :moving)

      Movement.mark_dirty(@map_name, :mob, 5001, 0)
      {_d1, rs1} = Coordinator.flush_snapshots(@map_name, %{}, 1)
      assert Map.has_key?(rs1, {:mob, 5001})

      Movement.mark_dirty(@map_name, :mob, 5001, 1)
      {_d2, rs2} = Coordinator.flush_snapshots(@map_name, rs1, 2)
      refute Map.has_key?(rs2, {:mob, 5001})
    end

    test "an over-budget entity set splits into multiple chunks sharing one server_tick" do
      register_player(character_id: 1001, x: 50, y: 50, view_range: 100)

      for id <- 1..400 do
        register_mob(instance_id: id, x: 50, y: 51, movement_state: :moving)
        Movement.mark_dirty(@map_name, :mob, id, 1)
      end

      {deliveries, _} = Coordinator.flush_snapshots(@map_name, %{}, 777)

      pid = self()
      assert [{^pid, chunks}] = deliveries
      assert length(chunks) >= 2
      ticks = chunks |> Enum.map(& &1.server_tick) |> Enum.uniq()
      assert [777] = ticks
    end

    test "a flush with no dirty units and no echoes yields no deliveries" do
      register_player(character_id: 1001, x: 50, y: 50)
      register_mob(instance_id: 5001, x: 52, y: 50, movement_state: :standing)

      {deliveries, recently_stopped} = Coordinator.flush_snapshots(@map_name, %{}, 1)

      assert deliveries == []
      assert recently_stopped == %{}
    end

    test "drained chunks are %Snapshot{} structs over the snapshots channel" do
      register_player(character_id: 1001, x: 50, y: 50)
      register_mob(instance_id: 5001, x: 52, y: 50, movement_state: :moving)
      Movement.mark_dirty(@map_name, :mob, 5001, 1)

      {[{_pid, chunks}], _} = Coordinator.flush_snapshots(@map_name, %{}, 1)

      assert Enum.all?(chunks, &match?(%NetSnapshot{}, &1))
    end
  end

  describe "handle_info(:broadcast_tick, ...)" do
    test "delivers each chunk to the player's pid via PlayerSession.send_packet/2" do
      # Players and mobs share one canonical map key (no `.gat`), matching the
      # coordinator's own clean name; the flush drains that name directly.
      # Regression test for mobs being invisible because they were keyed under a
      # `.gat`-suffixed name the player-side queries never matched.
      register_player(character_id: 1001, x: 50, y: 50, map_name: @map_name)
      register_mob(instance_id: 5001, x: 52, y: 50, movement_state: :moving, map_name: @map_name)
      Movement.mark_dirty(@map_name, :mob, 5001, 1)

      state = %Coordinator{
        map_name: @map_name,
        recently_stopped: %{},
        mobs_spawned: true,
        mobs_awake: true
      }

      assert {:noreply, %Coordinator{recently_stopped: %{}}} =
               Coordinator.handle_info(:broadcast_tick, state)

      assert_receive {:"$gen_cast", {:send_packet, %NetSnapshot{entities: [%{id: 5001}]}}}
    end
  end

  defp delivered_ids(deliveries) do
    deliveries
    |> Enum.flat_map(fn {_pid, chunks} -> chunks end)
    |> Enum.flat_map(& &1.entities)
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end
end
