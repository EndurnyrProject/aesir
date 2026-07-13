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
end
