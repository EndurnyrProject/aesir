defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcOwlTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Archer.AcOwl

  test "skill_name/0" do
    assert AcOwl.skill_name() == :ac_owl
  end

  test "dex_bonus returns the skill level" do
    assert AcOwl.dex_bonus(1, %{}) == 1
    assert AcOwl.dex_bonus(7, %{}) == 7
    assert AcOwl.dex_bonus(10, %{}) == 10
  end

  test "Catalog.by_id(43) resolves to :ac_owl" do
    assert {:ok, definition} = Catalog.by_id(43)
    assert definition.name == :ac_owl
  end

  test "Catalog.by_name(:ac_owl) resolves" do
    assert {:ok, definition} = Catalog.by_name(:ac_owl)
    assert definition.id == 43
  end

  test ":passive capability is registered in catalog" do
    assert {:ok, _module} = Catalog.passive_module_for(:ac_owl)
  end
end
