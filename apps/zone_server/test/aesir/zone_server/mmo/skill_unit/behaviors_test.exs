defmodule Aesir.ZoneServer.Mmo.SkillUnit.BehaviorsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.SkillUnit.Behaviors

  test "all/0 is empty while no unit behaviours are registered" do
    assert Behaviors.all() == []
  end

  test "module_for/1 returns :error for an unknown name" do
    assert Behaviors.module_for(:nonexistent) == :error
  end
end
