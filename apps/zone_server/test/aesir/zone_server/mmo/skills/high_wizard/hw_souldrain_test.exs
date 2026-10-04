defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwSouldrainTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.HighWizard.HwSouldrain

  @cold_bolt 14
  @storm_gust 89

  describe "kill_sp_gain/2" do
    test "a targeted magic kill grants mob_level * (95 + 15 * lv) / 100 SP" do
      kill = %{kill_bf: :magic, skill_id: @cold_bolt, mob_level: 50}

      assert HwSouldrain.kill_sp_gain(10, kill) == div(50 * 245, 100)
      assert HwSouldrain.kill_sp_gain(1, kill) == 55
    end

    test "any magic skill that is neither ground nor self counts, Resurrection on undead included" do
      assert HwSouldrain.kill_sp_gain(1, %{kill_bf: :magic, skill_id: 54, mob_level: 50}) == 55
    end

    test "ground skills, weapon blows and basic attacks grant nothing" do
      assert HwSouldrain.kill_sp_gain(5, %{kill_bf: :magic, skill_id: @storm_gust, mob_level: 50}) ==
               0

      assert HwSouldrain.kill_sp_gain(5, %{kill_bf: :melee, skill_id: @cold_bolt, mob_level: 50}) ==
               0

      assert HwSouldrain.kill_sp_gain(5, %{kill_bf: :magic, skill_id: nil, mob_level: 50}) == 0
    end
  end

  test "max_sp_rate_bonus/2 is 2% per level" do
    assert HwSouldrain.max_sp_rate_bonus(7, %{}) == 14
  end
end
