defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.OreTableTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.OreTable

  setup do
    on_exit(fn -> :persistent_term.erase(OreTable) end)
  end

  test "entries loads every ore discovery item and rate" do
    entries = OreTable.entries()

    assert length(entries) == 20
    assert {714, 1} in entries
    assert {1011, 12} in entries
  end

  test "reload rebuilds the catalog" do
    :persistent_term.put(OreTable, [])

    assert :ok = OreTable.reload()
    assert length(OreTable.entries()) == 20
  end
end
