defmodule Aesir.ZoneServer.Mmo.Skills.McInccarryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.McInccarry

  test "skill_name/0" do
    assert McInccarry.skill_name() == :mc_inccarry
  end

  test "max_weight_bonus returns 2000 per skill level" do
    assert McInccarry.max_weight_bonus(10, %{}) == 20_000
    assert McInccarry.max_weight_bonus(5, %{}) == 10_000
  end

  test "Catalog.by_id(36) resolves to :mc_inccarry" do
    assert {:ok, definition} = Catalog.by_id(36)
    assert definition.name == :mc_inccarry
  end

  test "Catalog.by_name(:mc_inccarry) resolves" do
    assert {:ok, definition} = Catalog.by_name(:mc_inccarry)
    assert definition.id == 36
  end

  test ":passive capability is registered in catalog" do
    assert {:ok, McInccarry} = Catalog.passive_module_for(:mc_inccarry)
  end
end
