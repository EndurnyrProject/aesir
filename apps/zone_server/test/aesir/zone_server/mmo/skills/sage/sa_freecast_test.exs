defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecastTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaFreecast

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

    @tag game_mode: :renewal
    test "attack_delay/2 scales the delay by the renewal rate" do
      assert SaFreecast.attack_delay(1, 1_000) == 550
      assert SaFreecast.attack_delay(10, 1_000) == 1_000
    end

    @tag game_mode: :pre_renewal
    test "attack_delay/2 lengthens the delay towards two seconds in classic" do
      assert SaFreecast.attack_delay(1, 1_000) == 1_450
      assert SaFreecast.attack_delay(10, 1_000) == 1_000
      assert SaFreecast.attack_delay(5, 500) == 875
    end
  end
end
