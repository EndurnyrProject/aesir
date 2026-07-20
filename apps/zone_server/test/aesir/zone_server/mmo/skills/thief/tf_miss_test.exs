defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfMissTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfMiss

  test "Catalog.by_id/1 resolves TF_MISS" do
    assert {:ok, definition} = Catalog.by_id(49)
    assert definition.name == :tf_miss
    assert definition.max_level == 10
    assert definition.target_type == :passive
  end

  test "Catalog.passive_module_for/1 resolves tf_miss" do
    assert {:ok, TfMiss} = Catalog.passive_module_for(:tf_miss)
  end

  test "flee_bonus is 3 * level" do
    assert TfMiss.flee_bonus(1, %{}) == 3
    assert TfMiss.flee_bonus(10, %{}) == 30
  end
end
