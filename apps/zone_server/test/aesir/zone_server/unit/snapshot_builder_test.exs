defmodule Aesir.ZoneServer.Unit.SnapshotBuilderTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  import ExUnit.CaptureLog

  alias Aesir.Net.Envelope
  alias Aesir.Net.Snapshot, as: NetSnapshot
  alias Aesir.Net.SnapshotEntity
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SnapshotBuilder
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

  describe "entities_for/1" do
    test "maps a player to its position, dir and standing move_state" do
      player_game_state(character_id: 1001, x: 50, y: 50, dir: 5) |> register_player()

      assert [%SnapshotEntity{id: 1001, x: 50, y: 50, dir: 5, move_state: 0, hp_pct: 100}] =
               SnapshotBuilder.entities_for([{:player, 1001}])
    end

    test "maps a moving unit to move_state 1" do
      player_game_state(movement_state: :moving) |> register_player()

      assert [%SnapshotEntity{move_state: 1}] = SnapshotBuilder.entities_for([{:player, 1001}])
    end

    test "maps a mob to its position, dir and hp_pct" do
      register_mob(instance_id: 5001, x: 52, y: 51, dir: 2, hp: 1000, max_hp: 1000)

      assert [%SnapshotEntity{id: 5001, x: 52, y: 51, dir: 2, move_state: 0, hp_pct: 100}] =
               SnapshotBuilder.entities_for([{:mob, 5001}])
    end

    test "computes hp_pct for a partially-damaged unit" do
      register_mob(instance_id: 5001, hp: 375, max_hp: 1000)

      assert [%SnapshotEntity{hp_pct: 38}] = SnapshotBuilder.entities_for([{:mob, 5001}])
    end

    test "guards against max_hp of zero" do
      register_mob(instance_id: 5001, hp: 0, max_hp: 0)

      assert [%SnapshotEntity{hp_pct: 0}] = SnapshotBuilder.entities_for([{:mob, 5001}])
    end

    test "skips units that are not registered" do
      register_mob(instance_id: 5001)

      assert [%SnapshotEntity{id: 5001}] =
               SnapshotBuilder.entities_for([{:mob, 5001}, {:mob, 9999}])
    end
  end

  describe "chunks_for/3" do
    test "returns a single chunk when the entities fit within the datagram budget" do
      entities = [
        %SnapshotEntity{id: 1001, x: 50, y: 50, dir: 3, move_state: 0, hp_pct: 100},
        %SnapshotEntity{id: 5001, x: 52, y: 50, dir: 1, move_state: 0, hp_pct: 100}
      ]

      assert [%NetSnapshot{} = chunk] = SnapshotBuilder.chunks_for(entities, {50, 50}, 123)
      assert chunk.server_tick == 123
      assert encoded_datagram_size(chunk) <= SnapshotBuilder.datagram_budget()
      assert MapSet.new(chunk.entities, & &1.id) == MapSet.new([1001, 5001])
    end

    test "splits an oversized entity set into multiple in-budget chunks sharing one server_tick" do
      entities =
        for id <- 1..400,
            do: %SnapshotEntity{id: id, x: 50, y: 51, dir: 0, move_state: 0, hp_pct: 100}

      chunks = SnapshotBuilder.chunks_for(entities, {50, 50}, 777)

      assert length(chunks) >= 2

      ticks = chunks |> Enum.map(& &1.server_tick) |> Enum.uniq()
      assert [777] = ticks

      for chunk <- chunks do
        assert encoded_datagram_size(chunk) <= SnapshotBuilder.datagram_budget()
      end
    end

    test "every chunk stays within the budget at the inner-length-prefix boundary" do
      entities =
        for id <- 1..400,
            do: %SnapshotEntity{id: id, x: 50, y: 51, dir: 7, move_state: 1, hp_pct: 99}

      chunks = SnapshotBuilder.chunks_for(entities, {50, 50}, 0)

      assert length(chunks) >= 2

      for chunk <- chunks do
        assert encoded_datagram_size(chunk) <= SnapshotBuilder.datagram_budget()
      end
    end

    test "chunk entity sets are disjoint and ordered nearest-first" do
      near = %SnapshotEntity{id: 1001, x: 50, y: 50, dir: 0, move_state: 0, hp_pct: 100}

      far =
        for id <- 1..400,
            do: %SnapshotEntity{id: 10_000 + id, x: 50, y: 51, dir: 0, move_state: 0, hp_pct: 100}

      chunks = SnapshotBuilder.chunks_for(far ++ [near], {50, 50}, 1)
      id_lists = Enum.map(chunks, fn chunk -> Enum.map(chunk.entities, & &1.id) end)
      all_ids = List.flatten(id_lists)

      assert all_ids == Enum.uniq(all_ids)
      assert hd(hd(id_lists)) == 1001
    end

    test "decimates entities beyond the chunk cap and logs how many were cut" do
      total = SnapshotBuilder.max_chunks() * 200

      entities =
        for id <- 1..total,
            do: %SnapshotEntity{id: id, x: 50, y: 51, dir: 0, move_state: 0, hp_pct: 100}

      {chunks, log} = with_log(fn -> SnapshotBuilder.chunks_for(entities, {50, 50}, 1) end)

      assert length(chunks) == SnapshotBuilder.max_chunks()
      packed = chunks |> Enum.flat_map(& &1.entities) |> length()
      assert packed < total + 1
      assert log =~ "snapshot"
    end
  end
end
