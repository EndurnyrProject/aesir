defmodule Aesir.ZoneServer.Mmo.MobSkill.DenylistTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist

  test "denied?/1 is false for any id while the seed list is empty" do
    refute Denylist.denied?(1)
    refute Denylist.denied?(19)
    refute Denylist.denied?(999_999)
  end
end
