defmodule Aesir.ZoneServer.Mmo.Combat.DamageSharedTest do
  @moduledoc """
  Tests for the type-agnostic damage tail shared by physical and magic calcs.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.DamageShared

  describe "apply_element/3" do
    test "neutral attack vs neutral defender is a 1.0 multiplier" do
      assert DamageShared.apply_element(100, :neutral, %{element: {:neutral, 1}}) == 100.0
    end

    test "applies a known weakness multiplier" do
      assert DamageShared.apply_element(100, :water, %{element: {:fire, 1}}) == 200.0
    end

    test "defaults to {:neutral, 1} when defender has no element" do
      assert DamageShared.apply_element(100, :neutral, %{}) == 100.0
    end

    test "passes damage through unchanged for a non-tuple element" do
      assert DamageShared.apply_element(100, :water, %{element: :fire}) == 100
    end
  end

  describe "apply_damage_multiplier/2" do
    test "0.5 bonus multiplies damage by 1.5" do
      assert DamageShared.apply_damage_multiplier(100, %{damage_multiplier: 0.5}) == 150.0
    end

    test "defaults to no change when the multiplier is absent" do
      assert DamageShared.apply_damage_multiplier(100, %{}) == 100.0
    end
  end

  describe "clamp_min_one/1" do
    test "clamps a fractional value below 1 up to 1" do
      assert DamageShared.clamp_min_one(0.4) == 1
    end

    test "truncates a value above 1" do
      assert DamageShared.clamp_min_one(176.85) == 176
    end
  end

  describe "roll/2" do
    test "returns min when max equals min" do
      assert DamageShared.roll(50, 50) == 50
    end

    test "returns min when max is below min" do
      assert DamageShared.roll(50, 40) == 50
    end

    test "stays within [min, max - 1] across many rolls" do
      for _ <- 1..1000 do
        result = DamageShared.roll(10, 14)
        assert result >= 10 and result <= 13
      end
    end

    test "an adjacent band (max == min + 1) is deterministic at min" do
      assert DamageShared.roll(7, 8) == 7
    end
  end
end
