defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.RecipesTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe

  setup do
    on_exit(fn -> :persistent_term.erase(Recipes) end)
  end

  test "all loads every imported recipe" do
    recipes = Recipes.all()

    assert length(recipes) == 293
    assert Enum.all?(recipes, &match?(%Recipe{}, &1))
  end

  test "by_id returns the matching recipe or :error" do
    assert {:ok, %Recipe{id: 0, product_id: 1101}} = Recipes.by_id(0)
    assert :error = Recipes.by_id(-1)
  end

  test "offerable filters by skill id and required skill level" do
    recipes = Recipes.offerable(99, 2)

    assert recipes != []
    assert Enum.all?(recipes, &(&1.skill_id == 99))
    assert Enum.all?(recipes, &(&1.skill_level <= 2))
    assert Enum.any?(recipes, &(&1.skill_level == 2))
    refute Enum.any?(recipes, &(&1.skill_level == 3))
  end

  test "a level-one weapon cast excludes tier-two and tier-three recipes" do
    recipes = Recipes.offerable(99, 1)

    assert recipes != []
    assert Enum.all?(recipes, &(&1.item_level == 1))
    refute Enum.any?(recipes, &(&1.item_level in [2, 3]))
  end

  test "preserves possession-only materials" do
    assert {:ok, %Recipe{materials: materials}} = Recipes.by_id(52)
    assert %{item_id: 7472, amount: 0} in materials
  end

  test "reload rebuilds the catalog" do
    :persistent_term.put(Recipes, %{all: [], by_id: %{}})

    assert :ok = Recipes.reload()
    assert length(Recipes.all()) == 293
  end
end
