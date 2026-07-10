defmodule Aesir.ZoneServer.Mmo.MobManagement.MobModeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode

  describe "from_ai_type/1" do
    test "decodes MONSTER_TYPE_04 (0x3885) to the aggressive melee set in ascending bit order" do
      assert MobMode.from_ai_type(4) == [
               :can_move,
               :aggressive,
               :can_attack,
               :angry,
               :change_target_melee,
               :change_target_chase
             ]
    end

    test "decodes MONSTER_TYPE_01 (0x81) to can_move + can_attack" do
      assert MobMode.from_ai_type(1) == [:can_move, :can_attack]
    end

    test "decodes MONSTER_TYPE_26 (0xB695) to its full ascending-bit set" do
      assert MobMode.from_ai_type(26) == [
               :can_move,
               :aggressive,
               :cast_sensor_idle,
               :can_attack,
               :cast_sensor_chase,
               :change_chase,
               :change_target_melee,
               :change_target_chase,
               :random_target
             ]
    end

    test "decodes MONSTER_TYPE_27 (0x8084) to aggressive + can_attack + random_target" do
      assert MobMode.from_ai_type(27) == [:aggressive, :can_attack, :random_target]
    end

    test "MONSTER_TYPE_06 (0x0) yields no modes" do
      assert MobMode.from_ai_type(6) == []
    end

    test "ai_type 0 (no Ai) yields no modes without raising" do
      assert MobMode.from_ai_type(0) == []
    end

    test "raises on a known-unused ai_type (14)" do
      assert_raise ArgumentError, ~r/14/, fn -> MobMode.from_ai_type(14) end
    end

    test "raises on an out-of-range ai_type" do
      assert_raise ArgumentError, ~r/99/, fn -> MobMode.from_ai_type(99) end
    end
  end

  describe "from_ai/1" do
    test "decodes the special Abr_Offensive name in ascending bit order" do
      assert MobMode.from_ai("Abr_Offensive") == [
               :can_move,
               :aggressive,
               :no_random_walk,
               :can_attack
             ]
    end

    test "decodes the special Abr_Passive name" do
      assert MobMode.from_ai("Abr_Passive") == [:can_move, :no_random_walk]
    end

    test "special names are case-insensitive" do
      assert MobMode.from_ai("abr_offensive") == MobMode.from_ai("Abr_Offensive")
    end

    test "a numeric string delegates to from_ai_type" do
      assert MobMode.from_ai("04") == MobMode.from_ai_type(4)
    end

    test "an integer delegates to from_ai_type" do
      assert MobMode.from_ai(4) == MobMode.from_ai_type(4)
    end

    test "0 and nil yield no modes" do
      assert MobMode.from_ai(0) == []
      assert MobMode.from_ai(nil) == []
    end

    test "raises on a genuinely unknown name" do
      assert_raise ArgumentError, ~r/Foo_Unknown/, fn -> MobMode.from_ai("Foo_Unknown") end
    end
  end
end
