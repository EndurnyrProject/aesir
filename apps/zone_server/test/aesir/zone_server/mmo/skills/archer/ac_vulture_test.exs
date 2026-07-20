defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcVultureTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Archer.AcVulture

  test "skill_name/0" do
    assert AcVulture.skill_name() == :ac_vulture
  end

  test "hit_bonus returns the skill level unconditionally" do
    assert AcVulture.hit_bonus(1, %{weapon_type: :dagger}) == 1
    assert AcVulture.hit_bonus(5, %{weapon_type: :dagger}) == 5
    assert AcVulture.hit_bonus(5, %{weapon_type: :bow}) == 5
    assert AcVulture.hit_bonus(10, %{}) == 10
  end

  test "range_bonus returns the skill level when wielding a bow" do
    assert AcVulture.range_bonus(5, %{weapon_type: :bow}) == 5
    assert AcVulture.range_bonus(10, %{weapon_type: :bow}) == 10
  end

  test "range_bonus returns 0 when not wielding a bow" do
    assert AcVulture.range_bonus(5, %{weapon_type: :dagger}) == 0
    assert AcVulture.range_bonus(5, %{weapon_type: :fist}) == 0
    assert AcVulture.range_bonus(5, %{}) == 0
  end

  test "Catalog.by_id(44) resolves to :ac_vulture" do
    assert {:ok, definition} = Catalog.by_id(44)
    assert definition.name == :ac_vulture
  end

  test "Catalog.by_name(:ac_vulture) resolves" do
    assert {:ok, definition} = Catalog.by_name(:ac_vulture)
    assert definition.id == 44
  end

  test ":passive capability is registered in catalog" do
    assert {:ok, _module} = Catalog.passive_module_for(:ac_vulture)
  end
end
