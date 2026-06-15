defmodule Aesir.ZoneServer.Mmo.ItemManagementTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  setup do
    potion = %ItemDefinition{
      id: 501,
      aegis_name: "Red_Potion",
      name: "Red Potion",
      type: :healing
    }

    index = %{all: [potion], by_id: %{501 => potion}, by_aegis: %{"Red_Potion" => potion}}
    :persistent_term.put(Items, index)
    on_exit(fn -> :persistent_term.erase(Items) end)

    %{potion: potion}
  end

  test "get_item_by_id resolves or reports not found", %{potion: potion} do
    assert {:ok, ^potion} = ItemManagement.get_item_by_id(501)
    assert {:error, :item_not_found} = ItemManagement.get_item_by_id(999_999)
  end

  test "get_item_by_aegis resolves or reports not found", %{potion: potion} do
    assert {:ok, ^potion} = ItemManagement.get_item_by_aegis("Red_Potion")
    assert {:error, :item_not_found} = ItemManagement.get_item_by_aegis("Nope")
  end

  test "get_all_items returns every definition", %{potion: potion} do
    assert [^potion] = ItemManagement.get_all_items()
  end
end
