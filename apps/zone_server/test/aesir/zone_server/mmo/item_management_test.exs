defmodule Aesir.ZoneServer.Mmo.ItemManagementTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  setup do
    %{unknown: build(:item_definition)}
  end

  test "get_item_by_id resolves a catalog item or reports not found", %{unknown: unknown} do
    assert {:ok, %ItemDefinition{id: 501, aegis_name: "Red_Potion"}} =
             ItemManagement.get_item_by_id(501)

    assert {:error, :item_not_found} = ItemManagement.get_item_by_id(unknown.id)
  end

  test "get_item_by_aegis resolves a catalog item or reports not found", %{unknown: unknown} do
    assert {:ok, %ItemDefinition{id: 501, aegis_name: "Red_Potion"}} =
             ItemManagement.get_item_by_aegis("Red_Potion")

    assert {:error, :item_not_found} = ItemManagement.get_item_by_aegis(unknown.aegis_name)
  end
end
