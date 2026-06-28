defmodule Aesir.ZoneServer.Unit.LookTypeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.LookType

  test "weapon/0 returns 2" do
    assert LookType.weapon() == 2
  end

  test "head_bottom/0 returns 3" do
    assert LookType.head_bottom() == 3
  end

  test "head_top/0 returns 4" do
    assert LookType.head_top() == 4
  end

  test "head_mid/0 returns 5" do
    assert LookType.head_mid() == 5
  end

  test "shield/0 returns 8" do
    assert LookType.shield() == 8
  end

  test "robe/0 returns 12" do
    assert LookType.robe() == 12
  end
end
