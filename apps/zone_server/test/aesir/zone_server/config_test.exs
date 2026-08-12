defmodule Aesir.ZoneServer.ConfigTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Config

  describe "max_party/0" do
    test "returns the configured default when unset" do
      assert Config.max_party() == 12
    end
  end

  describe "party_share_level/0" do
    test "returns the configured default when unset" do
      assert Config.party_share_level() == 15
    end
  end

  describe "party_even_share_bonus/0" do
    test "returns the configured default when unset" do
      assert Config.party_even_share_bonus() == 0
    end
  end

  describe "exp_bonus_attacker/0" do
    test "returns the configured default when unset" do
      assert Config.exp_bonus_attacker() == 25
    end
  end

  describe "boss_respawn_delay_percentage/0" do
    test "returns the configured default when unset" do
      assert Config.boss_respawn_delay_percentage() == 100
    end
  end

  describe "exp_bonus_max_attacker/0" do
    test "returns the configured default when unset" do
      assert Config.exp_bonus_max_attacker() == 12
    end
  end

  describe "natural_break_rate/0" do
    test "returns the configured default when unset" do
      assert Config.natural_break_rate() == 0
    end
  end

  describe "exp rate accessors" do
    test "default to 100 (1x) when unset" do
      assert Config.base_exp_rate() == 100
      assert Config.job_exp_rate() == 100
      assert Config.mvp_exp_rate() == 100
      assert Config.quest_exp_rate() == 100
    end
  end

  describe "drop_category/1" do
    test "classifies item types following rAthena" do
      assert Config.drop_category(:healing) == :heal
      assert Config.drop_category(:usable) == :use
      assert Config.drop_category(:cash) == :use
      assert Config.drop_category(:weapon) == :equip
      assert Config.drop_category(:armor) == :equip
      assert Config.drop_category(:pet_armor) == :equip
      assert Config.drop_category(:card) == :card
      assert Config.drop_category(:etc) == :common
      assert Config.drop_category(:pet_egg) == :common
      assert Config.drop_category(:ammo) == :common
      assert Config.drop_category(:delay_consume) == :common
    end
  end

  describe "item_drop_rate/1 and item_drop_bounds/1" do
    test "default to 1x rate and the 1..10000 clamp for every category" do
      for category <- [:common, :heal, :use, :equip, :card, :mvp, :treasure] do
        assert Config.item_drop_rate(category) == 100
        assert Config.item_drop_bounds(category) == {1, 10_000}
      end
    end
  end

  describe "level cap accessors" do
    test "default high enough to leave the per-job tables in charge" do
      assert Config.max_base_level() == 999
      assert Config.max_job_level() == 999
    end
  end
end
