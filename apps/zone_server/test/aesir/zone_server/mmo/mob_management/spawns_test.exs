defmodule Aesir.ZoneServer.Mmo.MobManagement.SpawnsTest do
  @moduledoc """
  Runtime-shape coverage for the spawn index.

  The importer's own tests exercise parsing, but they cannot catch a loader that
  fails to deserialize a field into its struct — the failure mode that shipped
  `mvp_drops` as raw string-keyed maps in Task 5. These assert the shape that
  reaches callers.
  """
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns

  setup :setup_ets_tables

  describe "for_map/1 boss spawns" do
    test "returns boss entries for a map known to host one" do
      assert {:ok, spawns} = Spawns.for_map("gld_dun03")

      baphomet = Enum.find(spawns, &(&1.mob == 1039))

      assert %MobSpawn{} = baphomet
      assert baphomet.respawn_time == 28_800_000
      assert baphomet.respawn_variance == 600_000
    end

    test "the boss entry references a boss-classified mob" do
      assert {:ok, spawns} = Spawns.for_map("gld_dun03")
      assert %MobSpawn{mob: mob_id} = Enum.find(spawns, &(&1.mob == 1039))

      assert {:ok, mob} = Mobs.by_id(mob_id)
      assert :boss in mob.modes
    end

    test "every spawn deserializes as a MobSpawn struct with an integer variance" do
      assert {:ok, spawns} = Spawns.for_map("gld_dun03")

      assert Enum.all?(spawns, &match?(%MobSpawn{}, &1))
      assert Enum.all?(spawns, &is_integer(&1.respawn_variance))
    end

    test "a spawn without a source delay2 carries a zero variance" do
      spawns = Spawns.all() |> Map.values() |> List.flatten()

      assert Enum.any?(spawns, &(&1.respawn_variance == 0))
      assert Enum.any?(spawns, &(&1.respawn_variance > 0))
    end
  end
end
