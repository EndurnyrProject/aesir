defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McVendingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McVending

  describe "skill data" do
    test "mc_vending loads from the catalog as a passive skill at id 41" do
      assert {:ok, definition} = Catalog.by_id(41)
      assert {:ok, ^definition} = Catalog.by_name(:mc_vending)
      assert definition.name == :mc_vending
      assert definition.display_name == "Vending"
      assert definition.target_type == :passive
      assert definition.max_level == 10
    end

    test "is registered with the passive capability" do
      assert :passive in McVending.__skill_capabilities__()
    end
  end

  describe "max_slots/1" do
    test "is 2 + level, capped at 12" do
      assert McVending.max_slots(1) == 3
      assert McVending.max_slots(5) == 7
      assert McVending.max_slots(10) == 12
      assert McVending.max_slots(11) == 12
    end
  end
end
