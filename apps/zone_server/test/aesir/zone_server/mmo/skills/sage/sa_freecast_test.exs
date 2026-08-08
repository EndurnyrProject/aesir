defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecastTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast

  describe "definition" do
    test "is catalogued under id 278 as a 10-level passive" do
      assert {:ok, definition} = Catalog.by_id(278)
      assert definition.name == :sa_freecast
      assert definition.max_level == 10
      assert definition.target_type == :passive
    end

    test "publishes no capabilities - the behavior lives in the cast machine" do
      assert SaFreecast.__skill_capabilities__() == []
    end
  end

  describe "speed_rate/1" do
    test "is rAthena's 175 - 5 * lv, as a percentage of the base walk speed" do
      assert SaFreecast.speed_rate(1) == 170
      assert SaFreecast.speed_rate(5) == 150
      assert SaFreecast.speed_rate(10) == 125
    end
  end

  describe "amotion_rate/1" do
    test "is rAthena's renewal 5 * (lv + 10), faster below level 10 and neutral at 10" do
      assert SaFreecast.amotion_rate(1) == 55
      assert SaFreecast.amotion_rate(5) == 75
      assert SaFreecast.amotion_rate(10) == 100
    end
  end
end
