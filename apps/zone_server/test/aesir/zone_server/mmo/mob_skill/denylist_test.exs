defmodule Aesir.ZoneServer.Mmo.MobSkill.DenylistTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist

  test "denied?/1 is false for an id never swept into the list" do
    refute Denylist.denied?(1)
    refute Denylist.denied?(19)
    refute Denylist.denied?(999_999)
  end

  test "denied?/1 and reason_for/1 agree for a real sweep-populated entry" do
    assert Denylist.denied?(8)
    assert Denylist.reason_for(8) =~ "SM_ENDURE"
  end
end
