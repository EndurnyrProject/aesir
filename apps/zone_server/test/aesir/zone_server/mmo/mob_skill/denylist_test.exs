defmodule Aesir.ZoneServer.Mmo.MobSkill.DenylistTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  test "denied?/1 is false for an id never swept into the list" do
    refute Denylist.denied?(1)
    refute Denylist.denied?(19)
    refute Denylist.denied?(999_999)
  end

  test "denied?/1 and reason_for/1 agree for a real sweep-populated entry" do
    assert Denylist.denied?(8)
    assert Denylist.reason_for(8) =~ "SM_ENDURE"
  end

  test "denied?/1 and reason_for/1 agree for HT_TALKIEBOX, which resolves in the catalog" do
    assert {:ok, definition} = Catalog.by_id(125)
    assert {:ok, _module} = Catalog.active_module_for(definition.name)

    assert Denylist.denied?(125)
    assert Denylist.reason_for(125) =~ "HT_TALKIEBOX"
  end
end
