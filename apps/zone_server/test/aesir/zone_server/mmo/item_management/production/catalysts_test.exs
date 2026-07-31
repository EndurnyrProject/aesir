defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.CatalystsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Catalysts

  test "uses and consumes only the first elemental stone" do
    assert {0, :fire, [994]} = Catalysts.resolve([994, 995, 996])
  end

  test "counts and consumes every star crumb" do
    assert {3, nil, [1000, 1000, 1000]} = Catalysts.resolve([1000, 1000, 1000])
  end

  test "ignores unknown item ids" do
    assert {0, nil, []} = Catalysts.resolve([9_999, 9_998, 9_997])
  end

  test "considers only the first three selected items" do
    assert {3, nil, [1000, 1000, 1000]} = Catalysts.resolve([1000, 1000, 1000, 994])
  end

  test "does not consume anvils" do
    assert {1, nil, [1000]} = Catalysts.resolve([986, 1000, 989])
  end
end
