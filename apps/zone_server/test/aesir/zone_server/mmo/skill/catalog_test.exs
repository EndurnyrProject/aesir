defmodule Aesir.ZoneServer.Mmo.Skill.CatalogTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  test "by_id/1 loads AL_INCAGI with correct structure" do
    assert {:ok, %Definition{} = def} = Catalog.by_id(29)
    assert def.name == :al_incagi
    assert def.max_level == 10
    assert def.target_type == :target_ally
    assert length(def.sp_cost) == def.max_level
    assert length(def.duration) == def.max_level
  end

  test "by_name/1 finds the same record" do
    assert {:ok, %Definition{id: 29}} = Catalog.by_name(:al_incagi)
  end

  test "by_id/1 returns :error for an unknown skill" do
    assert :error = Catalog.by_id(999_999)
  end
end
