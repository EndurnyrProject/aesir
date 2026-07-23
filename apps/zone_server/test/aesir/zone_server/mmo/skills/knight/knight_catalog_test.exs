defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnightCatalogTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  test "KN_RIDING is discovered by id and by name as a max-level 1 passive" do
    assert {:ok, by_id} = Catalog.by_id(63)
    assert {:ok, by_name} = Catalog.by_name(:kn_riding)
    assert by_id == by_name
    assert by_id.name == :kn_riding
    assert by_id.display_name == "Peco Peco Riding"
    assert by_id.max_level == 1
    assert by_id.target_type == :passive

    assert {:ok, module} = Catalog.passive_module_for(:kn_riding)
    assert :passive in module.__skill_capabilities__()
  end

  test "KN_CAVALIERMASTERY is discovered by id and by name as a max-level 5 passive" do
    assert {:ok, by_id} = Catalog.by_id(64)
    assert {:ok, by_name} = Catalog.by_name(:kn_cavaliermastery)
    assert by_id == by_name
    assert by_id.name == :kn_cavaliermastery
    assert by_id.display_name == "Cavalier Mastery"
    assert by_id.max_level == 5
    assert by_id.target_type == :passive

    assert {:ok, module} = Catalog.passive_module_for(:kn_cavaliermastery)
    assert :passive in module.__skill_capabilities__()
  end
end
