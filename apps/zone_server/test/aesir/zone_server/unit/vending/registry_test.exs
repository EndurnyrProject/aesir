defmodule Aesir.ZoneServer.Unit.Vending.RegistryTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

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
end
