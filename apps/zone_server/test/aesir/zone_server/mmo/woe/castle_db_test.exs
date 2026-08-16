defmodule Aesir.ZoneServer.Mmo.Woe.CastleDbTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle

  describe "reload/0" do
    test "loads the 20 FE castles into :persistent_term" do
      assert :ok = CastleDb.reload()
      assert length(CastleDb.all()) == 20
    end
  end

  describe "lookups" do
    setup do
      :ok = CastleDb.reload()
      :ok
    end

    test "by_id/1 resolves a known castle with tuple coordinates" do
      assert {:ok, %Castle{} = castle} = CastleDb.by_id(16)
      assert castle.map == "prtg_cas02"
      assert castle.emperium == {157, 174}
      assert castle.respawn == {94, 56}
    end

    test "by_map/1 resolves a known castle with tuple coordinates" do
      assert {:ok, %Castle{} = castle} = CastleDb.by_map("prtg_cas01")
      assert castle.id == 15
      assert castle.emperium == {197, 197}
      assert castle.respawn == {107, 180}
    end

    test "unknown id and map return :error" do
      assert :error = CastleDb.by_id(999)
      assert :error = CastleDb.by_map("nonexistent_map")
    end
  end

  describe "%Castle{}" do
    test "exposes emperium and respawn as positive-integer tuples" do
      assert {:ok, castle} = CastleDb.by_id(16)

      assert match?(
               {x, y} when is_integer(x) and x > 0 and is_integer(y) and y > 0,
               castle.emperium
             )

      assert match?(
               {x, y} when is_integer(x) and x > 0 and is_integer(y) and y > 0,
               castle.respawn
             )
    end
  end
end
