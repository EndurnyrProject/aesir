defmodule Aesir.ZoneServer.Mmo.WalkSpeedTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.WalkSpeed

  describe "slows and hastes" do
    test "only the strongest slow counts" do
      # Decrease AGI (25) and Quagmire (50): 150 * 150 / 100.
      assert WalkSpeed.calculate(150, %{movement_speed: 50}, %{}) == 225
    end

    test "the mount haste comes off before the slow and the haste" do
      # Riding (25) with Curse (300) and Increase AGI (25): 100 - 25 + 300 - 25.
      modifiers = %{move_haste2: 25, movement_speed: 300, haste_rate: 25}

      assert WalkSpeed.calculate(150, modifiers, %{}) == 525
    end

    test "the rate never falls below 40" do
      assert WalkSpeed.calculate(150, %{haste_rate: 80, move_haste2: 25}, %{}) == 60
    end

    test "item haste competes with status haste instead of stacking" do
      assert WalkSpeed.calculate(150, %{haste_rate: 25}, %{item_speed: 25}) == 112
      assert WalkSpeed.calculate(150, %{haste_rate: 25}, %{item_speed: 40}) == 90
    end

    test "a negative item speed is a slow competing with status slows" do
      assert WalkSpeed.calculate(150, %{movement_speed: 25}, %{item_speed: -10}) == 187
      assert WalkSpeed.calculate(150, %{movement_speed: 10}, %{item_speed: -25}) == 187
    end

    test "Improve Dodge's haste competes with the other hastes" do
      assert WalkSpeed.calculate(150, %{haste_rate: 25}, %{improve_dodge_haste: 10}) == 112
      assert WalkSpeed.calculate(150, %{}, %{improve_dodge_haste: 10}) == 135
    end
  end

  describe "player-only rate terms" do
    test "Tunnel Drive's slow replaces every other slow" do
      # Level 5 (90) under Curse (300): only 90 counts.
      modifiers = %{movement_speed: 300}

      assert WalkSpeed.calculate(150, modifiers, %{tunnel_drive_slow: 90}) == 285
    end

    test "Free Cast's rate replaces the whole slow and haste fold" do
      modifiers = %{movement_speed: 300, haste_rate: 25, move_haste2: 25}

      assert WalkSpeed.calculate(150, modifiers, %{cast_speed_rate: 125}) == 187
    end

    test "a monster ignores the player terms it cannot have" do
      assert WalkSpeed.calculate(150, %{movement_speed: 25}, nil) == 187
    end
  end

  describe "the speed stage" do
    test "Pushcart lengthens the base delay before the rate applies" do
      # Pushcart 5: 150 + 150 * 25 / 100 = 187, then Increase AGI: 187 * 75 / 100.
      assert WalkSpeed.calculate(150, %{walk_delay_rate: 25, haste_rate: 25}, %{}) == 140
    end

    test "Steel Body fixes the speed and Defender floors it" do
      assert WalkSpeed.calculate(150, %{haste_rate: 25, walk_speed_override: 200}, %{}) == 200
      assert WalkSpeed.calculate(150, %{haste_rate: 25, walk_speed_floor: 200}, %{}) == 200
      assert WalkSpeed.calculate(150, %{movement_speed: 300, walk_speed_floor: 200}, %{}) == 600
    end

    test "the speed is clamped to 20..1000 and a player never walks faster than 50" do
      assert WalkSpeed.calculate(400, %{movement_speed: 300}, nil) == 1_000
      assert WalkSpeed.calculate(40, %{haste_rate: 60}, nil) == 20
      assert WalkSpeed.calculate(100, %{haste_rate: 60}, nil) == 40
      assert WalkSpeed.calculate(100, %{haste_rate: 60}, %{}) == 50
    end
  end
end
