defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  setup do
    potion = %ItemDefinition{
      id: 501,
      aegis_name: "Red_Potion",
      name: "Red Potion",
      type: :healing
    }

    knife = %ItemDefinition{id: 1201, aegis_name: "Knife", name: "Knife", type: :weapon}

    index = %{
      all: [potion, knife],
      by_id: %{501 => potion, 1201 => knife},
      by_aegis: %{"Red_Potion" => potion, "Knife" => knife}
    }

    :persistent_term.put(Items, index)
    on_exit(fn -> :persistent_term.erase(Items) end)

    %{potion: potion, knife: knife}
  end

  test "by_id resolves a known item", %{potion: potion} do
    assert {:ok, ^potion} = Items.by_id(501)
  end

  test "by_id returns :error for an unknown id" do
    assert :error = Items.by_id(999_999)
  end

  test "by_aegis resolves a known item", %{knife: knife} do
    assert {:ok, ^knife} = Items.by_aegis("Knife")
  end

  test "by_aegis returns :error for an unknown aegis" do
    assert :error = Items.by_aegis("Nonexistent")
  end

  test "all returns every definition", %{potion: potion, knife: knife} do
    assert [^potion, ^knife] = Items.all()
  end
end
