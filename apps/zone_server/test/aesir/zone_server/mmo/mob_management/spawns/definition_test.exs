defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns.DefinitionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs.Poring
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition

  defmodule TestSpawns do
    alias Aesir.ZoneServer.Mmo.MobManagement.Mobs.Poring

    use Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition,
      map: "test_map",
      spawns: [
        %{mob: Poring, amount: 3, respawn_time: 10_000, area: %{x: 110, y: 203, xs: 5, ys: 5}},
        %{mob: Poring, amount: 1, respawn_time: 5_000, area: %{x: 0, y: 0}}
      ]
  end

  defp valid_opts do
    [
      map: "valid_map",
      spawns: [
        %{mob: Poring, amount: 1, respawn_time: 1_000, area: %{x: 10, y: 10}}
      ]
    ]
  end

  describe "use macro" do
    test "generates map_name/0" do
      assert TestSpawns.map_name() == "test_map"
    end

    test "generates spawns/0 with built structs" do
      assert [
               %MobSpawn{
                 mob: Poring,
                 amount: 3,
                 respawn_time: 10_000,
                 spawn_area: %MobSpawn.SpawnArea{x: 110, y: 203, xs: 5, ys: 5}
               },
               %MobSpawn{mob: Poring, amount: 1, respawn_time: 5_000}
             ] = TestSpawns.spawns()
    end

    test "area xs/ys default to 0" do
      [_first, %MobSpawn{spawn_area: area}] = TestSpawns.spawns()

      assert area == %MobSpawn.SpawnArea{x: 0, y: 0, xs: 0, ys: 0}
    end
  end

  describe "build!/2 validation" do
    test "builds valid options" do
      assert %{map: "valid_map", spawns: [%MobSpawn{mob: Poring}]} =
               Definition.build!(valid_opts(), __MODULE__)
    end

    test "raises when map is missing" do
      assert_raise ArgumentError, ~r/map/, fn ->
        Definition.build!(Keyword.delete(valid_opts(), :map), __MODULE__)
      end
    end

    test "raises on non-positive amount" do
      opts = [
        map: "valid_map",
        spawns: [%{mob: Poring, amount: 0, respawn_time: 1_000, area: %{x: 1, y: 1}}]
      ]

      assert_raise ArgumentError, ~r/amount/, fn ->
        Definition.build!(opts, __MODULE__)
      end
    end

    test "raises on unknown spawn keys" do
      opts = [
        map: "valid_map",
        spawns: [%{mob: Poring, amount: 1, respawn_time: 1_000, delay: 5, area: %{x: 1, y: 1}}]
      ]

      assert_raise ArgumentError, ~r/unknown.*delay/is, fn ->
        Definition.build!(opts, __MODULE__)
      end
    end

    test "raises on unknown area keys" do
      opts = [
        map: "valid_map",
        spawns: [%{mob: Poring, amount: 1, respawn_time: 1_000, area: %{x: 1, y: 1, radius: 3}}]
      ]

      assert_raise ArgumentError, ~r/unknown.*radius/is, fn ->
        Definition.build!(opts, __MODULE__)
      end
    end
  end
end
