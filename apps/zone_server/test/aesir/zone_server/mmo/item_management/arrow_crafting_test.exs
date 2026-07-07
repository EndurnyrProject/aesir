defmodule Aesir.ZoneServer.Mmo.ItemManagement.ArrowCraftingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting
  alias Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting.Recipe
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  describe "all/0" do
    test "loads the imported recipe table" do
      recipes = ArrowCrafting.all()

      assert length(recipes) > 100
      assert Enum.all?(recipes, &match?(%Recipe{}, &1))
    end

    test "every source and product resolves in the item catalog" do
      for %Recipe{source_id: source_id, makes: makes} <- ArrowCrafting.all() do
        assert {:ok, _} = Items.by_id(source_id)

        for %{item_id: item_id, amount: amount} <- makes do
          assert {:ok, _} = Items.by_id(item_id)
          assert amount > 0
        end
      end
    end
  end

  describe "for_source/1" do
    test "resolves a known recipe (Branch of Dead Tree -> 40 Mute Arrows)" do
      assert {:ok, %Recipe{source_id: 604, makes: [%{item_id: 1769, amount: 40}]}} =
               ArrowCrafting.for_source(604)
    end

    test "returns :error for an item that crafts nothing" do
      assert :error = ArrowCrafting.for_source(501)
    end
  end
end
