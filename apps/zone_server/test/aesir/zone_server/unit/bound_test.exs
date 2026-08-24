defmodule Aesir.ZoneServer.Unit.BoundTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Bound

  test "applies the bound transfer policy" do
    for {bound, transferable?, storable?} <- [
          {0, true, true},
          {1, false, true},
          {2, false, false},
          {3, false, false},
          {4, false, false}
        ] do
      item = %InventoryItem{bound: bound}

      assert Bound.transferable?(item) == transferable?
      assert Bound.sellable?(item) == transferable?
      assert Bound.vendable?(item) == transferable?
      assert Bound.storable?(item) == storable?
    end
  end

  test "inverts the personal storage policy for account-bound and guild-bound items" do
    account_bound = %InventoryItem{bound: 1}
    guild_bound = %InventoryItem{bound: 2}

    assert Bound.storable?(account_bound)
    refute Bound.guild_storable?(account_bound)
    refute Bound.storable?(guild_bound)
    assert Bound.guild_storable?(guild_bound)
  end
end
