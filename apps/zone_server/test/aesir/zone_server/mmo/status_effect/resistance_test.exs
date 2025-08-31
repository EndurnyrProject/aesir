defmodule Aesir.ZoneServer.Mmo.StatusEffect.ResistanceTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance

  describe "calculate_success_rate/3" do
    test "calculates physical resistance based on VIT" do
      # VIT reduces success rate by 1% per point
      assert Resistance.calculate_success_rate(:physical, %{vit: 50}, 100) == 50.0
      assert Resistance.calculate_success_rate(:physical, %{vit: 30}, 80) == 50.0
      assert Resistance.calculate_success_rate(:physical, %{vit: 100}, 90) == 0.0
    end

    test "calculates magical resistance based on MDEF" do
      # MDEF reduces success rate by 1% per point
      assert Resistance.calculate_success_rate(:magical, %{mdef: 20}, 100) == 80.0
      assert Resistance.calculate_success_rate(:magical, %{mdef: 50}, 75) == 25.0
      assert Resistance.calculate_success_rate(:magical, %{mdef: 100}, 80) == 0.0
    end

    test "returns base success rate for unknown resistance types" do
      assert Resistance.calculate_success_rate(:unknown, %{vit: 50}, 100) == 100
      assert Resistance.calculate_success_rate(nil, %{vit: 50}, 75) == 75
    end

    test "handles missing stats gracefully" do
      # Missing VIT
      assert Resistance.calculate_success_rate(:physical, %{}, 100) == 100
      assert Resistance.calculate_success_rate(:physical, %{vit: nil}, 100) == 100

      # Missing MDEF
      assert Resistance.calculate_success_rate(:magical, %{}, 100) == 100
      assert Resistance.calculate_success_rate(:magical, %{mdef: nil}, 100) == 100
    end

    test "never returns negative success rate" do
      assert Resistance.calculate_success_rate(:physical, %{vit: 200}, 100) == 0.0
      assert Resistance.calculate_success_rate(:magical, %{mdef: 150}, 50) == 0.0
    end
  end

  describe "calculate_duration/2" do
    test "calculates duration reduction based on VIT and LUK" do
      # Formula: duration * (100 - (VIT + LUK/3)) / 100
      stats = %{vit: 60, luk: 30}
      # 60 + 30/3 = 60 + 10 = 70% reduction
      # 10000 * (100 - 70) / 100 = 3000
      assert Resistance.calculate_duration(10000, stats) == 3000
    end

    test "handles fractional LUK values" do
      stats = %{vit: 50, luk: 20}
      # 50 + 20/3 = 50 + 6.666... = 56.666... reduction
      # 10000 * (100 - 56.666) / 100 = 4333.33...
      assert_in_delta Resistance.calculate_duration(10000, stats), 4333, 1
    end

    test "handles missing stats" do
      # Missing both or invalid stats - returns base duration
      assert Resistance.calculate_duration(10000, %{}) == 10000

      # Missing VIT - returns base duration
      assert Resistance.calculate_duration(10000, %{luk: 30}) == 10000

      # Missing LUK - returns base duration
      assert Resistance.calculate_duration(10000, %{vit: 50}) == 10000

      # Nil values - returns base duration
      assert Resistance.calculate_duration(10000, %{vit: nil, luk: nil}) == 10000
    end

    test "caps reduction at 100%" do
      stats = %{vit: 90, luk: 60}
      # 90 + 60/3 = 90 + 20 = 110%, capped at 100%
      # Duration becomes 0
      assert Resistance.calculate_duration(10000, stats) == 0
    end

    test "never returns negative duration" do
      # VIT + LUK/3 = 0, so no reduction
      stats = %{vit: 0, luk: 0}
      assert Resistance.calculate_duration(10000, stats) == 10000
    end
  end

  describe "apply_resistance/4" do
    test "applies both success rate and duration reduction for physical status" do
      definition = %{resistance_type: :physical}
      stats = %{vit: 40, luk: 30}
      base_success = 100
      base_duration = 10000

      {success_rate, duration} =
        Resistance.apply_resistance(definition, stats, base_success, base_duration)

      # Success rate: 100 - 40 = 60%
      assert success_rate == 60.0

      # Duration reduction: 40 + 30/3 = 50%
      # Duration: 10000 * (100 - 50) / 100 = 5000ms
      assert duration == 5000
    end

    test "applies both success rate and duration reduction for magical status" do
      definition = %{resistance_type: :magical}
      stats = %{mdef: 25, vit: 30, luk: 60}
      base_success = 80
      base_duration = 20000

      {success_rate, duration} =
        Resistance.apply_resistance(definition, stats, base_success, base_duration)

      # Success rate: 80 - 25 = 55%
      assert success_rate == 55.0

      # Duration reduction: 30 + 60/3 = 50%
      # Duration: 20000 * (100 - 50) / 100 = 10000ms
      assert duration == 10000
    end

    test "handles complete resistance (0% success rate)" do
      definition = %{resistance_type: :physical}
      stats = %{vit: 100, luk: 30}
      base_success = 90
      base_duration = 10000

      {success_rate, duration} =
        Resistance.apply_resistance(definition, stats, base_success, base_duration)

      # Success rate: 90 - 100 = 0% (clamped)
      assert success_rate == 0.0

      # Duration would be reduced but doesn't matter if success is 0%
      # Duration reduction: 100 + 30/3 = 110% (capped at 100%)
      # Duration: 10000 * 0 / 100 = 0ms
      assert duration == 0
    end

    test "handles no resistance type (defaults to physical)" do
      definition = %{}
      stats = %{vit: 50, luk: 30, mdef: 20}
      base_success = 75
      base_duration = 15000

      {success_rate, duration} =
        Resistance.apply_resistance(definition, stats, base_success, base_duration)

      # No resistance type defaults to physical (uses VIT)
      # Success rate: 75 - 50 = 25%
      assert success_rate == 25.0

      # Duration reduction: 50 + 30/3 = 60%
      # Duration: 15000 * (100 - 60) / 100 = 6000ms
      assert duration == 6000
    end

    test "handles missing stats gracefully" do
      definition = %{resistance_type: :physical}
      stats = %{}
      base_success = 100
      base_duration = 10000

      {success_rate, duration} =
        Resistance.apply_resistance(definition, stats, base_success, base_duration)

      # No stats means no resistance
      assert success_rate == 100
      assert duration == 10000
    end

    test "can reduce duration to 0 with complete resistance" do
      definition = %{resistance_type: :physical}
      stats = %{vit: 100, luk: 0}
      base_success = 50
      base_duration = 5000

      {_success_rate, duration} =
        Resistance.apply_resistance(definition, stats, base_success, base_duration)

      # Duration reduction: 100% makes it 0ms
      assert duration == 0
    end
  end

  describe "should_apply_resistance?/1" do
    test "returns false for status effects with no_resistance property" do
      definition = %{properties: [:no_resistance, :debuff]}
      refute Resistance.should_apply_resistance?(definition)
    end

    test "returns true for status effects without no_resistance property" do
      definition = %{properties: [:debuff, :prevent_movement]}
      assert Resistance.should_apply_resistance?(definition)
    end

    test "returns true when properties list is empty" do
      definition = %{properties: []}
      assert Resistance.should_apply_resistance?(definition)
    end

    test "returns true when properties is nil" do
      definition = %{}
      assert Resistance.should_apply_resistance?(definition)
    end

    test "handles properties not being a list" do
      definition = %{properties: :invalid}
      assert Resistance.should_apply_resistance?(definition)
    end
  end

  describe "roll_success/1" do
    test "always succeeds with 100% rate" do
      # Test multiple times to ensure consistency
      for _ <- 1..10 do
        assert Resistance.roll_success(100.0) == true
      end
    end

    test "always fails with 0% rate" do
      # Test multiple times to ensure consistency
      for _ <- 1..10 do
        assert Resistance.roll_success(0.0) == false
      end
    end

    test "handles negative rates as failure" do
      assert Resistance.roll_success(-10) == false
    end

    test "handles rates over 100% as success" do
      assert Resistance.roll_success(150) == true
    end

    test "returns boolean for intermediate rates" do
      # Just verify it returns a boolean, not testing randomness
      result = Resistance.roll_success(50)
      assert is_boolean(result)
    end
  end

  describe "integration scenarios" do
    test "high VIT character resists physical status effects" do
      # Tank character with high VIT
      definition = %{resistance_type: :physical}
      tank_stats = %{vit: 90, luk: 20}

      {success_rate, duration} = Resistance.apply_resistance(definition, tank_stats, 100, 30000)

      # Only 10% chance to be affected
      assert success_rate == 10.0
      # Duration heavily reduced: 90 + 20/3 = 96.666%
      assert duration == 1000
    end

    test "high MDEF character resists magical status effects" do
      # Mage with high MDEF
      definition = %{resistance_type: :magical}
      mage_stats = %{mdef: 75, vit: 40, luk: 30}

      {success_rate, duration} = Resistance.apply_resistance(definition, mage_stats, 100, 20000)

      # 25% chance to be affected
      assert success_rate == 25.0
      # Duration: 40 + 30/3 = 50% reduction
      assert duration == 10000
    end

    test "balanced character has moderate resistance" do
      definition = %{resistance_type: :physical}
      balanced_stats = %{vit: 50, luk: 50, mdef: 50}

      {success_rate, duration} =
        Resistance.apply_resistance(definition, balanced_stats, 100, 15000)

      # 50% chance to be affected
      assert success_rate == 50.0
      # Duration: 50 + 50/3 = 66.666% reduction
      assert_in_delta duration, 5000, 1
    end

    test "low stat character has minimal resistance" do
      definition = %{resistance_type: :magical}
      novice_stats = %{vit: 10, luk: 10, mdef: 5}

      {success_rate, duration} = Resistance.apply_resistance(definition, novice_stats, 100, 10000)

      # 95% chance to be affected
      assert success_rate == 95.0
      # Duration: 10 + 10/3 = 13.333% reduction
      assert_in_delta duration, 8666, 1
    end
  end
end
