defmodule Aesir.ZoneServer.Mmo.SkillUnit.BehaviorsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.SkillUnit.Behaviors
  alias Aesir.ZoneServer.Mmo.SkillUnit.Behaviors.WzStormgust

  test "all/0 lists the registered unit behaviours" do
    assert Behaviors.all() == [WzStormgust]
  end

  test "module_for/1 resolves a registered behaviour by skill name" do
    assert {:ok, WzStormgust} = Behaviors.module_for(:wz_stormgust)
  end

  test "module_for/1 returns :error for an unknown name" do
    assert Behaviors.module_for(:nonexistent) == :error
  end
end
