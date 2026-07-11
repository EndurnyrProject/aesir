defmodule Mix.Tasks.Aesir.Gen.ConstantsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.EffectId
  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.Emotion
  alias Aesir.ZoneServer.Mmo.Opt1
  alias Aesir.ZoneServer.Mmo.Opt2
  alias Aesir.ZoneServer.Mmo.Option
  alias Mix.Tasks.Aesir.Gen.Constants

  describe "parse_enum/3" do
    test "auto-increments bare members from 0" do
      source = """
      enum unrelated { FOO_A };
      enum e_demo : uint16 {
        DEMO_FIRST = 0,
        DEMO_SECOND,
        DEMO_THIRD,
      };
      """

      assert {:ok, %{first: 0, second: 1, third: 2}} =
               Constants.parse_enum(source, "e_demo", "DEMO_")
    end

    test "honors explicit hex values and resumes auto-increment from them" do
      source = """
      enum e_demo : uint32 {
        DEMO_NONE = 0x0,
        DEMO_HIDE = 0x00000002,
        DEMO_NEXT,
      };
      """

      assert {:ok, %{none: 0, hide: 2, next: 3}} =
               Constants.parse_enum(source, "e_demo", "DEMO_")
    end

    test "honors a negative explicit value" do
      source = """
      enum e_demo {
        DEMO_NONE = -1,
        DEMO_HIT1,
        DEMO_HIT2,
      };
      """

      assert {:ok, %{none: -1, hit1: 0, hit2: 1}} =
               Constants.parse_enum(source, "e_demo", "DEMO_")
    end

    test "strips line and block comments" do
      source = """
      enum e_demo {
        DEMO_NONE = 0, // a trailing comment
        DEMO_ONE, /* an inline block */
        DEMO_TWO,
        // a whole comment line
        DEMO_THREE,
      };
      """

      assert {:ok, %{none: 0, one: 1, two: 2, three: 3}} =
               Constants.parse_enum(source, "e_demo", "DEMO_")
    end

    test "stops at the enum's closing brace and ignores later enums" do
      source = """
      enum e_demo {
        DEMO_A = 5,
      };
      enum e_other {
        OTHER_B = 99,
      };
      """

      assert {:ok, %{a: 5}} = Constants.parse_enum(source, "e_demo", "DEMO_")
    end

    test "returns an error when the enum is not found" do
      assert {:error, :enum_not_found} =
               Constants.parse_enum("not an enum", "e_demo", "DEMO_")
    end
  end

  describe "generated resolver modules" do
    test "resolve the expected rAthena ids" do
      assert Opt1.id(:stone) == 1
      assert Option.id(:hide) == 2
      assert EffectId.id(:hit1) == 0
      assert EffectId.id(:none) == -1
      assert Opt2.id(:poison) == 1
      assert Efst.id(:provoke) == 0
      assert Emotion.id(:surprise) == 0
    end

    test "an unknown atom resolves to nil" do
      assert Opt1.id(:not_a_real_constant) == nil
      assert Efst.id(:not_a_real_constant) == nil
    end
  end
end
