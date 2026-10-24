defmodule Aesir.ZoneServer.Mmo.MobManagement.SummonGroupsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.SummonGroups

  test "every group draws an existing, non-clone monster" do
    for type <- 0..5, _ <- 1..20 do
      id = SummonGroups.pick(type)

      assert id > 0 and id not in 3_999..20_020
      assert {:ok, _definition} = Mobs.by_id(id)
    end
  end

  test "a type outside the groups draws nothing" do
    assert SummonGroups.pick(6) == 0
    assert SummonGroups.pick(-1) == 0
  end
end
