defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HunterPassivesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFalcon
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSteelcrow

  test "Falconry Mastery is a cataloged passive permission" do
    assert {:ok, definition} = Catalog.by_id(127)
    assert definition.name == :ht_falcon
    assert definition.display_name == "Falconry Mastery"
    assert definition.max_level == 1
    assert definition.target_type == :passive
    assert {:ok, HtFalcon} = Catalog.passive_module_for(:ht_falcon)
  end

  test "Steel Crow is a cataloged passive damage input" do
    assert {:ok, definition} = Catalog.by_id(128)
    assert definition.name == :ht_steelcrow
    assert definition.display_name == "Steel Crow"
    assert definition.max_level == 10
    assert definition.target_type == :passive
    assert {:ok, HtSteelcrow} = Catalog.passive_module_for(:ht_steelcrow)
  end
end
