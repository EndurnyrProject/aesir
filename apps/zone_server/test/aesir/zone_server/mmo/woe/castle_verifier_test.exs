defmodule Aesir.ZoneServer.Mmo.Woe.CastleVerifierTest do
  use ExUnit.Case, async: false
  use Mimic

  setup :verify_on_exit!

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleVerifier

  describe "verify!/0" do
    test "passes when every emperium and respawn cell is walkable" do
      stub(CastleDb, :all, fn -> [castle(emperium: {5, 5}, respawn: {10, 10})] end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      assert :ok = CastleVerifier.verify!()
    end

    test "raises naming the map, kind, and coordinate of a non-walkable cell" do
      stub(CastleDb, :all, fn -> [castle(emperium: {5, 5}, respawn: {10, 10})] end)

      stub(MapCache, :walkable?, fn
        "aldeg_cas01", 5, 5 -> false
        _, _, _ -> true
      end)

      assert_raise RuntimeError, ~r/aldeg_cas01.*emperium.*\(5, 5\)/, fn ->
        CastleVerifier.verify!()
      end
    end

    test "raises when a castle map is not in the cache" do
      stub(CastleDb, :all, fn -> [castle(emperium: {5, 5}, respawn: {10, 10})] end)
      stub(MapCache, :walkable?, fn _, _, _ -> false end)

      assert_raise RuntimeError, ~r/Neuschwanstein/, fn ->
        CastleVerifier.verify!()
      end
    end
  end

  defp castle(opts) do
    %Castle{
      id: 1,
      map: "aldeg_cas01",
      name: "Neuschwanstein",
      client_id: 0,
      emperium: Keyword.fetch!(opts, :emperium),
      respawn: Keyword.fetch!(opts, :respawn)
    }
  end
end
