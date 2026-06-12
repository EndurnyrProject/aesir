defmodule Aesir.ZoneServer.Mmo.MobManagement.SpawnsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns

  defmodule GoodSpawns do
    alias Aesir.ZoneServer.Mmo.MobManagement.Mobs.Poring

    use Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition,
      map: "good_map",
      spawns: [
        %{mob: Poring, amount: 1, respawn_time: 1_000, area: %{x: 1, y: 1}}
      ]
  end

  defmodule BadSpawns do
    use Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition,
      map: "bad_map",
      spawns: [
        %{mob: NotAMobModule, amount: 1, respawn_time: 1_000, area: %{x: 1, y: 1}}
      ]
  end

  describe "validate_mob_refs!/1" do
    test "passes when every referenced module is a mob definition" do
      assert :ok = Spawns.validate_mob_refs!(GoodSpawns)
    end

    test "raises naming the map and module on a bad reference" do
      assert_raise ArgumentError, ~r/bad_map.*NotAMobModule/s, fn ->
        Spawns.validate_mob_refs!(BadSpawns)
      end
    end
  end
end
