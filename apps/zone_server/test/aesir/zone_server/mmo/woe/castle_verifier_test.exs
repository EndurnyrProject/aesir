defmodule Aesir.ZoneServer.Mmo.Woe.CastleVerifierTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleVerifier

  setup :set_mimic_from_context

  describe "verify!/0" do
    test "passes when every emperium and respawn cell is walkable" do
      stub(CastleDb, :all, fn -> [build(:castle, name: "Neuschwanstein")] end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)
      stub(MapCache, :get!, fn _ -> %{xs: 400, ys: 400} end)

      assert :ok = CastleVerifier.verify!()
    end

    test "raises naming the map, kind, and coordinate of a non-walkable cell" do
      stub(CastleDb, :all, fn -> [build(:castle, name: "Neuschwanstein")] end)
      stub(MapCache, :get!, fn _ -> %{xs: 400, ys: 400} end)

      stub(MapCache, :walkable?, fn
        "aldeg_cas01", 5, 5 -> false
        _, _, _ -> true
      end)

      assert_raise RuntimeError, ~r/aldeg_cas01.*emperium.*\(5, 5\)/, fn ->
        CastleVerifier.verify!()
      end
    end

    test "raises when a castle map is not in the cache" do
      stub(CastleDb, :all, fn -> [build(:castle, name: "Neuschwanstein")] end)
      stub(MapCache, :walkable?, fn _, _, _ -> false end)
      stub(MapCache, :get!, fn _ -> %{xs: 400, ys: 400} end)

      assert_raise RuntimeError, ~r/Neuschwanstein/, fn ->
        CastleVerifier.verify!()
      end
    end

    test "raises naming a non-walkable treasure cell as :treasure" do
      stub(CastleDb, :all, fn ->
        [build(:castle, treasure: %{box_id: 1_324, cells: [{20, 20}, {21, 21}]})]
      end)

      stub(MapCache, :get!, fn _ -> %{xs: 400, ys: 400} end)

      stub(MapCache, :walkable?, fn
        "aldeg_cas01", 21, 21 -> false
        _, _, _ -> true
      end)

      assert_raise RuntimeError, ~r/aldeg_cas01.*treasure.*\(21, 21\)/, fn ->
        CastleVerifier.verify!()
      end
    end

    test "raises naming an out-of-bounds guardian cell as :guardian" do
      stub(CastleDb, :all, fn ->
        [
          build(:castle,
            guardians: [
              %{type: :soldier, cell: {30, 30}},
              %{type: :archer, cell: {401, 31}}
            ]
          )
        ]
      end)

      stub(MapCache, :walkable?, fn _, _, _ -> true end)
      stub(MapCache, :get!, fn "aldeg_cas01" -> %{xs: 400, ys: 400} end)

      assert_raise RuntimeError, ~r/aldeg_cas01.*guardian.*\(401, 31\)/, fn ->
        CastleVerifier.verify!()
      end
    end

    test "raises naming a castle map with no mob region set" do
      stub(CastleDb, :all, fn ->
        [build(:castle, map: "custom_cas01")]
      end)

      stub(MapCache, :walkable?, fn _, _, _ -> true end)
      stub(MapCache, :get!, fn _ -> %{xs: 400, ys: 400} end)

      assert_raise RuntimeError, ~r/custom_cas01/, fn ->
        CastleVerifier.verify!()
      end
    end

    test "passes with an in-bounds guardian cell that is not walkable" do
      stub(CastleDb, :all, fn ->
        [
          build(:castle,
            treasure: %{box_id: 1_324, cells: [{100, 200}]},
            guardians: [%{type: :soldier, cell: {399, 399}}]
          )
        ]
      end)

      stub(MapCache, :walkable?, fn
        "aldeg_cas01", 5, 5 -> true
        "aldeg_cas01", 10, 10 -> true
        "aldeg_cas01", 100, 200 -> true
        _, _, _ -> false
      end)

      stub(MapCache, :get!, fn "aldeg_cas01" -> %{xs: 400, ys: 400} end)

      assert :ok = CastleVerifier.verify!()
    end
  end
end
