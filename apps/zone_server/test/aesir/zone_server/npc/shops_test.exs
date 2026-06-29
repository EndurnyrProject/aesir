defmodule Aesir.ZoneServer.Npc.ShopsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shop.Registry
  alias Aesir.ZoneServer.Npc.Shops

  setup do
    :persistent_term.erase(Shops)
    on_exit(fn -> :persistent_term.erase(Shops) end)
    :ok
  end

  describe "for_map/1" do
    test "loads the Tool Dealer with its items parsed (price nil when omitted)" do
      assert {:ok, [%Shop{id: "prontera_tool_dealer", name: "Tool Dealer", sprite: 85} = shop]} =
               Shops.for_map("prontera")

      assert %{nameid: 501, price: 50} in shop.items
      assert %{nameid: 502, price: nil} in shop.items
    end

    test "returns :error for a map with no shops" do
      assert :error = Shops.for_map("nonexistent")
    end
  end

  describe "all/0" do
    test "returns shops keyed by map name" do
      assert %{"prontera" => [%Shop{} | _]} = Shops.all()
    end
  end

  describe "reload/0" do
    test "rebuilds the cached index" do
      assert :ok = Shops.reload()
      assert {:ok, _} = Shops.for_map("prontera")
    end
  end

  describe "persistent_term warming" do
    test "for_map/1 populates :persistent_term without an explicit reload" do
      assert :persistent_term.get(Shops, nil) == nil

      Shops.for_map("prontera")

      assert %{} = :persistent_term.get(Shops, nil)
    end
  end

  describe "Shop.Registry.fetch/1" do
    test "resolves a known shop gid to {:ok, shop}" do
      {:ok, [shop]} = Shops.for_map("prontera")
      gid = Registry.entity_id(shop)

      assert {:ok, ^shop} = Registry.fetch(gid)
    end

    test "returns :error for an unknown gid" do
      Shops.for_map("prontera")

      assert :error = Registry.fetch(0)
    end
  end

  describe "Shop.Registry.by_cell/3" do
    test "finds the shop at its placement cell" do
      assert {:ok, %Shop{id: "prontera_tool_dealer"}} = Registry.by_cell("prontera", 150, 60)
    end

    test "returns :error for an empty cell" do
      assert :error = Registry.by_cell("prontera", 1, 1)
    end
  end

  describe "Shop.Registry.entries/0" do
    test "returns all shops as a flat list" do
      assert [%Shop{id: "prontera_tool_dealer"}] = Registry.entries()
    end
  end
end
