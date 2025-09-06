defmodule Aesir.ZoneServer.Mmo.Combat.ElementModifiersTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers

  describe "get_modifier/3" do
    test "neutral vs neutral should be 1.0" do
      assert ElementModifiers.get_modifier(:neutral, :neutral, 1) == 1.0
    end

    test "water vs fire should be 2.0 (weakness)" do
      assert ElementModifiers.get_modifier(:water, :fire, 1) == 2.0
    end

    test "fire vs water should be 0.9 (resistance)" do
      assert ElementModifiers.get_modifier(:fire, :water, 1) == 0.9
    end

    test "poison vs poison should be 0.0 (immunity)" do
      assert ElementModifiers.get_modifier(:poison, :poison, 1) == 0.0
    end

    test "holy vs undead should be 1.25 (strong vs undead)" do
      assert ElementModifiers.get_modifier(:holy, :undead, 1) == 1.25
    end

    test "element level 2 should increase resistance" do
      # Base water vs water is 0.25 at level 1
      base_modifier = ElementModifiers.get_modifier(:water, :water, 1)
      level_2_modifier = ElementModifiers.get_modifier(:water, :water, 2)

      assert base_modifier == 0.25
      assert level_2_modifier < base_modifier
    end

    test "element level 2 should increase weakness" do
      # Base water vs fire is 2.0 at level 1
      base_modifier = ElementModifiers.get_modifier(:water, :fire, 1)
      level_2_modifier = ElementModifiers.get_modifier(:water, :fire, 2)

      assert base_modifier == 2.0
      assert level_2_modifier > base_modifier
    end

    test "unknown element should default to 1.0" do
      # Using invalid atoms should not crash
      assert ElementModifiers.get_modifier(:invalid, :neutral, 1) == 1.0
      assert ElementModifiers.get_modifier(:neutral, :invalid, 1) == 1.0
    end
  end
end
