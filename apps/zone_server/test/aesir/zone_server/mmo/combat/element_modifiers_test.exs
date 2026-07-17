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

  describe "id/1" do
    test "maps each element atom to its rAthena e_element ordinal" do
      assert ElementModifiers.id(:neutral) == 0
      assert ElementModifiers.id(:water) == 1
      assert ElementModifiers.id(:earth) == 2
      assert ElementModifiers.id(:fire) == 3
      assert ElementModifiers.id(:wind) == 4
      assert ElementModifiers.id(:poison) == 5
      assert ElementModifiers.id(:holy) == 6
      assert ElementModifiers.id(:shadow) == 7
      assert ElementModifiers.id(:ghost) == 8
      assert ElementModifiers.id(:undead) == 9
    end

    test "unknown element falls back to 0 (neutral)" do
      assert ElementModifiers.id(:invalid) == 0
    end
  end

  describe "get_modifier/4 ratio bonus" do
    # rAthena battle.cpp:531-551 (renewal): the field's enchant points are added
    # to the element table's ratio, after the defense-level scaling.
    test "adds the bonus percentage points on top of the element ratio" do
      assert ElementModifiers.get_modifier(:fire, :earth, 1, 20) == 2.2
    end

    test "a zero bonus leaves the ratio untouched" do
      assert ElementModifiers.get_modifier(:fire, :earth, 1, 0) ==
               ElementModifiers.get_modifier(:fire, :earth, 1)
    end

    test "the bonus applies after the defense-level scaling, not before" do
      # fire vs water is 0.9 at level 1; level 4 scales it to 0.36, then +0.20.
      assert_in_delta ElementModifiers.get_modifier(:fire, :water, 4, 20), 0.56, 0.0001
    end
  end
end
