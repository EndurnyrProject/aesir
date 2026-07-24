defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBeastbaneTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtBeastbane

  test "is catalogued as the level 10 passive Hunter skill" do
    assert {:ok, HtBeastbane} = Catalog.passive_module_for(:ht_beastbane)

    definition = HtBeastbane.definition()
    assert definition.id == 126
    assert definition.name == :ht_beastbane
    assert definition.display_name == "Beast Bane"
    assert definition.max_level == 10
    assert definition.target_type == :passive
  end
end
