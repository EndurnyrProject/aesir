defmodule Aesir.ZoneServer.Unit.Vending.RegistryTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Vending.Registry

  setup :setup_ets_tables

  describe "put/get/remove" do
    test "put then get returns the stored shop" do
      shop = %{title: "Cheap Pots", items: [%{index: 0, nameid: 501, amount: 5, price: 100}]}

      assert :ok = Registry.put(42, self(), shop)
      assert {:ok, ^shop} = Registry.get(42)
    end

    test "get returns :error when no shop is open" do
      assert :error = Registry.get(999)
    end

    test "remove deletes the shop" do
      assert :ok = Registry.put(42, self(), %{title: "Shop"})
      assert :ok = Registry.remove(42)
      assert :error = Registry.get(42)
    end

    test "put replaces an existing shop" do
      assert :ok = Registry.put(42, self(), %{title: "Old"})
      assert :ok = Registry.put(42, self(), %{title: "New"})
      assert {:ok, %{title: "New"}} = Registry.get(42)
    end
  end

  describe "list_near/4" do
    setup do
      shop = fn id -> %{title: "Shop #{id}"} end

      SpatialIndex.add_unit(:player, 1, 100, 100, "prontera")
      SpatialIndex.add_unit(:player, 2, 105, 102, "prontera")
      SpatialIndex.add_unit(:player, 3, 200, 200, "prontera")
      SpatialIndex.add_unit(:player, 4, 100, 100, "morocc")

      Registry.put(1, self(), shop.(1))
      Registry.put(2, self(), shop.(2))
      Registry.put(3, self(), shop.(3))
      Registry.put(4, self(), shop.(4))

      :ok
    end

    test "returns only shops within range on the same map" do
      result = Registry.list_near("prontera", 100, 100, 14)

      ids = result |> Enum.map(fn {unit_id, _shop} -> unit_id end) |> Enum.sort()

      assert ids == [1, 2]
    end

    test "excludes vendors on other maps even when coordinates match" do
      result = Registry.list_near("morocc", 100, 100, 14)

      assert [{4, _shop}] = result
    end

    test "returns the shop value alongside the unit_id" do
      assert [{1, %{title: "Shop 1"}}] = Registry.list_near("prontera", 100, 100, 1)
    end

    test "excludes shops whose vendor has no position" do
      Registry.put(77, self(), %{title: "Ghost"})

      result = Registry.list_near("prontera", 100, 100, 14)
      ids = Enum.map(result, fn {unit_id, _shop} -> unit_id end)

      refute 77 in ids
    end
  end
end
