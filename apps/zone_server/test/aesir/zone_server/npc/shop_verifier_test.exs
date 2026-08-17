defmodule Aesir.ZoneServer.Npc.ShopVerifierTest do
  use ExUnit.Case, async: true
  import Mimic
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.ShopVerifier

  setup :verify_on_exit!

  defp shop(overrides) do
    struct!(
      Shop,
      Keyword.merge(
        [
          id: "s",
          map: "prontera",
          x: 150,
          y: 60,
          dir: 4,
          sprite: 85,
          name: "T",
          items: [%{nameid: 501, price: 50}]
        ],
        overrides
      )
    )
  end

  describe "verify/1" do
    test "returns :ok for a shop on a walkable cell with known items" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      assert :ok = ShopVerifier.verify([shop([])])
    end

    test "flags a shop on an unknown map" do
      stub(MapCache, :exists?, fn _ -> false end)
      stub(MapCache, :walkable?, fn _, _, _ -> false end)

      assert {:error, errors} = ShopVerifier.verify([shop([])])
      assert Enum.any?(errors, &match?({:unknown_map, %Shop{}}, &1))
    end
  end

  describe "verify!/1" do
    test "passes the real prontera.yml shops" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      assert :ok = ShopVerifier.verify!(Shops.all())
    end

    test "raises when a shop is on an unknown map" do
      stub(MapCache, :exists?, fn _ -> false end)
      stub(MapCache, :walkable?, fn _, _, _ -> false end)

      assert_raise ArgumentError, fn -> ShopVerifier.verify!([shop([])]) end
    end

    test "raises when a shop cell is not walkable" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> false end)

      assert_raise ArgumentError, fn -> ShopVerifier.verify!([shop([])]) end
    end

    test "raises when a shop sells an item that does not resolve" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      assert_raise ArgumentError, fn ->
        ShopVerifier.verify!([shop(items: [%{nameid: 99_999_999, price: nil}])])
      end
    end

    test "does not warn when two shops share a cell but have distinct ids" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      shops = [shop(id: "Tool Dealer#yuno"), shop(id: "Tool Dealer#Extended_Yuno")]

      log = capture_log(fn -> assert :ok = ShopVerifier.verify!(shops) end)

      refute log =~ "shadowed"
    end

    test "warns but does not raise when two shops share a cell and id" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      shops = [shop(id: "dup"), shop(id: "dup")]

      log = capture_log(fn -> assert :ok = ShopVerifier.verify!(shops) end)

      assert log =~ "sharing id"
      assert log =~ "shadowed"
    end
  end
end
