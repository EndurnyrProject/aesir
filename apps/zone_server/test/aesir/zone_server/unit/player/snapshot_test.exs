defmodule Aesir.ZoneServer.Unit.Player.SnapshotTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  import ExUnit.CaptureLog
  import Mimic

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.Envelope
  alias Aesir.Net.Snapshot, as: NetSnapshot
  alias Aesir.Net.SnapshotEntity
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Snapshot
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp encoded_datagram_size(%NetSnapshot{} = snap) do
    {:ok, _iodata, size} = Envelope.encode(%Envelope{seq: 0xFFFF_FFFF, body: {:snapshot, snap}})
    size + 1
  end

  defp player_game_state(attrs) do
    base = %PlayerState{
      character_id: 1001,
      account_id: 2001,
      map_name: "prontera",
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

    Map.merge(base, Map.new(attrs))
  end

  defp register_player(game_state) do
    SpatialIndex.add_unit(
      :player,
      game_state.character_id,
      game_state.x,
      game_state.y,
      game_state.map_name
    )

    UnitRegistry.register_unit(:player, game_state.character_id, PlayerState, game_state, self())
    game_state
  end

  defp register_mob(attrs) do
    mob = mob_state(attrs)
    SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)
    UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, nil)
    mob
  end

  defp mob_state(attrs) do
    %{
      instance_id: 5001,
      map_name: "prontera",
      x: 52,
      y: 50,
      dir: 1,
      movement_state: :standing,
      hp: 1000,
      max_hp: 1000
    }
    |> Map.merge(Map.new(attrs))
    |> then(&struct(MobState, &1))
  end

  describe "build/1" do
    test "returns a Snapshot with a populated server_tick" do
      game_state = player_game_state([]) |> register_player()

      assert %NetSnapshot{server_tick: tick} = Snapshot.build(game_state)
      assert tick > 0
    end

    test "includes the player itself with its own position, dir and standing move_state" do
      game_state = player_game_state(x: 50, y: 50, dir: 5) |> register_player()

      %NetSnapshot{entities: entities} = Snapshot.build(game_state)

      assert %SnapshotEntity{x: 50, y: 50, dir: 5, move_state: 0, hp_pct: 100} =
               Enum.find(entities, &(&1.id == 1001))
    end

    test "maps a moving unit to move_state 1" do
      game_state = player_game_state(movement_state: :moving) |> register_player()

      %NetSnapshot{entities: entities} = Snapshot.build(game_state)

      assert %SnapshotEntity{move_state: 1} = Enum.find(entities, &(&1.id == 1001))
    end

    test "includes nearby mobs with their position, dir and hp_pct" do
      game_state = player_game_state([]) |> register_player()
      register_mob(instance_id: 5001, x: 52, y: 51, dir: 2, hp: 1000, max_hp: 1000)

      %NetSnapshot{entities: entities} = Snapshot.build(game_state)

      assert %SnapshotEntity{x: 52, y: 51, dir: 2, move_state: 0, hp_pct: 100} =
               Enum.find(entities, &(&1.id == 5001))
    end

    test "computes hp_pct for a partially-damaged unit" do
      game_state = player_game_state([]) |> register_player()
      register_mob(instance_id: 5001, hp: 375, max_hp: 1000)

      %NetSnapshot{entities: entities} = Snapshot.build(game_state)

      assert %SnapshotEntity{hp_pct: 38} = Enum.find(entities, &(&1.id == 5001))
    end

    test "guards against max_hp of zero" do
      game_state = player_game_state([]) |> register_player()
      register_mob(instance_id: 5001, hp: 0, max_hp: 0)

      %NetSnapshot{entities: entities} = Snapshot.build(game_state)

      assert %SnapshotEntity{hp_pct: 0} = Enum.find(entities, &(&1.id == 5001))
    end

    test "returns exactly the units inside the player's view_range" do
      game_state = player_game_state(x: 50, y: 50, view_range: 5) |> register_player()
      register_mob(instance_id: 5001, x: 53, y: 50)
      register_mob(instance_id: 5002, x: 200, y: 200)

      %NetSnapshot{entities: entities} = Snapshot.build(game_state)

      ids = entities |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == [1001, 5001]
    end
  end

  describe "build_chunks/1" do
    test "returns a single chunk when the AoI fits within the datagram budget" do
      game_state = player_game_state([]) |> register_player()
      register_mob(instance_id: 5001, x: 52, y: 50)

      assert [%NetSnapshot{} = chunk] = Snapshot.build_chunks(game_state)
      assert encoded_datagram_size(chunk) <= Snapshot.datagram_budget()
      assert MapSet.new(chunk.entities, & &1.id) == MapSet.new([1001, 5001])
    end

    test "splits an oversized AoI into multiple in-budget chunks sharing one server_tick" do
      game_state = player_game_state(x: 50, y: 50, view_range: 20) |> register_player()
      for id <- 1..400, do: register_mob(instance_id: 10_000 + id, x: 50, y: 51)

      chunks = Snapshot.build_chunks(game_state)

      assert length(chunks) >= 2

      ticks = chunks |> Enum.map(& &1.server_tick) |> Enum.uniq()
      assert [_single_tick] = ticks

      for chunk <- chunks do
        assert encoded_datagram_size(chunk) <= Snapshot.datagram_budget()
      end
    end

    test "every chunk stays within the datagram budget at the inner-length-prefix boundary" do
      stub(ServerTick, :now, fn -> 0 end)

      game_state = player_game_state(x: 50, y: 50, view_range: 20) |> register_player()

      for id <- 1..400 do
        register_mob(
          instance_id: 5_000_000 + id,
          x: 50,
          y: 51,
          dir: 7,
          movement_state: :moving,
          hp: 99,
          max_hp: 100
        )
      end

      chunks = Snapshot.build_chunks(game_state)

      assert length(chunks) >= 2

      for chunk <- chunks do
        assert encoded_datagram_size(chunk) <= Snapshot.datagram_budget()
      end
    end

    test "chunk entity sets are disjoint and ordered nearest-first" do
      game_state = player_game_state(x: 50, y: 50, view_range: 20) |> register_player()
      for id <- 1..400, do: register_mob(instance_id: 10_000 + id, x: 50, y: 51)

      chunks = Snapshot.build_chunks(game_state)
      id_lists = Enum.map(chunks, fn chunk -> Enum.map(chunk.entities, & &1.id) end)
      all_ids = List.flatten(id_lists)

      assert all_ids == Enum.uniq(all_ids)
      assert hd(hd(id_lists)) == 1001
    end

    test "decimates far entities beyond the chunk cap and logs how many were cut" do
      game_state = player_game_state(x: 50, y: 50, view_range: 20) |> register_player()
      total = Snapshot.max_chunks() * 200
      for id <- 1..total, do: register_mob(instance_id: 10_000 + id, x: 50, y: 51)

      {chunks, log} =
        with_log(fn -> Snapshot.build_chunks(game_state) end)

      assert length(chunks) == Snapshot.max_chunks()
      packed = chunks |> Enum.flat_map(& &1.entities) |> length()
      assert packed < total + 1
      assert log =~ "snapshot"
    end
  end
end
