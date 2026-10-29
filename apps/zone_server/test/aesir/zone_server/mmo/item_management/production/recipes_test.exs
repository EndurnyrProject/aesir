defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.RecipesTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe

  setup do
    on_exit(fn -> :persistent_term.erase(Recipes) end)
  end

  @tag game_mode: :renewal
  test "all loads every Renewal recipe" do
    recipes = Recipes.all()

    assert length(recipes) == 293
    assert Enum.all?(recipes, &match?(%Recipe{}, &1))
  end

  @tag game_mode: :pre_renewal
  test "all loads every pre-renewal recipe" do
    recipes = Recipes.all()

    assert length(recipes) == 258
    assert Enum.all?(recipes, &match?(%Recipe{}, &1))
  end

  test "reload rebuilds the catalog" do
    expected = Recipes.all()
    :persistent_term.put(Recipes, %{all: [], by_id: %{}})

    assert :ok = Recipes.reload()
    assert Recipes.all() == expected
  end
end
