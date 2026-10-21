defmodule Aesir.ZoneServer.Unit.BoundTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Bound

  test "applies the bound transfer policy" do
    for {bound, transferable?} <- [{0, true}, {1, false}, {2, false}, {3, false}, {4, false}] do
      item = %InventoryItem{bound: bound}

      assert Bound.transferable?(item) == transferable?
      assert Bound.sellable?(item) == transferable?
      assert Bound.vendable?(item) == transferable?
    end
  end
end
