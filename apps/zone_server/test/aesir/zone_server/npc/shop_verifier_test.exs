defmodule Aesir.ZoneServer.Npc.ShopVerifierTest do
  use ExUnit.Case, async: true
  import Mimic
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.ShopVerifier
  alias Aesir.ZoneServer.Npc.Warps

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

  defp stub_no_collisions do
    stub(NpcRegistry, :entries, fn -> [] end)
    stub(Warps, :all, fn -> %{} end)
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
      stub_no_collisions()

      assert :ok = ShopVerifier.verify!(Shops.all())
    end

    test "raises when a shop is on an unknown map" do
      stub(MapCache, :exists?, fn _ -> false end)
      stub(MapCache, :walkable?, fn _, _, _ -> false end)
      stub_no_collisions()

      assert_raise ArgumentError, fn -> ShopVerifier.verify!([shop([])]) end
    end

    test "raises when a shop cell is not walkable" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> false end)
      stub_no_collisions()

      assert_raise ArgumentError, fn -> ShopVerifier.verify!([shop([])]) end
    end

    test "raises when a shop sells an item that does not resolve" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)
      stub_no_collisions()

      assert_raise ArgumentError, fn ->
        ShopVerifier.verify!([shop(items: [%{nameid: 99_999_999, price: nil}])])
      end
    end

    test "warns but does not raise when a shop cell collides with an NPC placement" do
      stub(MapCache, :exists?, fn _ -> true end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)
      stub(Warps, :all, fn -> %{} end)

      stub(NpcRegistry, :entries, fn ->
        [{SomeNpc, struct!(Placement, map: "prontera", x: 150, y: 60, sprite: 1)}]
      end)

      log = capture_log(fn -> assert :ok = ShopVerifier.verify!([shop([])]) end)

      assert log =~ "collides"
    end
  end
end
