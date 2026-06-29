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

  defp sample_shop, do: Shops.all() |> Map.values() |> List.flatten() |> hd()

  describe "for_map/1" do
    test "loads shops for a populated map with their items parsed" do
      shop = sample_shop()

      assert {:ok, shops} = Shops.for_map(shop.map)
      assert shop in shops

      assert %Shop{id: id, map: map, name: name} = shop
      assert is_binary(id) and id != ""
      assert is_binary(map) and map != ""
      assert is_binary(name)
      assert is_integer(shop.x) and is_integer(shop.y)
      assert is_integer(shop.dir) and is_integer(shop.sprite)

      assert Enum.all?(shop.items, fn item ->
               is_integer(item.nameid) and (is_nil(item.price) or is_integer(item.price))
             end)
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
      assert {:ok, [%Shop{} | _]} = Shops.for_map("prontera")
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
      shop = sample_shop()
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
      shop = sample_shop()

      assert {:ok, ^shop} = Registry.by_cell(shop.map, shop.x, shop.y)
    end

    test "returns :error for an empty cell" do
      assert :error = Registry.by_cell("nonexistent", 1, 1)
    end
  end

  describe "Shop.Registry.entries/0" do
    test "returns all shops as a flat list" do
      assert [%Shop{} | _] = Registry.entries()
    end
  end
end
