defmodule Aesir.ZoneServer.Mmo.Skill.CastTimeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  defp definition(cast_time, fixed_cast_time \\ []) do
    %Definition{
      id: 83,
      name: :test_skill,
      display_name: "Test Skill",
      max_level: 10,
      cast_time: cast_time,
      fixed_cast_time: fixed_cast_time
    }
  end

  describe "compute/3" do
    test "instant when the base cast time is 0" do
      assert CastTime.compute(definition([0]), 1, %{dex: 50, int: 50}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "instant when the cast_time list is empty for the level" do
      assert CastTime.compute(definition([]), 1, %{dex: 50, int: 50}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "fixed cast defaults to 20% of base when no fixed_cast_time is set" do
      assert %{fixed: 200} = CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0})
    end

    test "explicit fixed_cast_time overrides the 20% default" do
      assert %{fixed: 350} =
               CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0})
    end

    test "variable is 0 once 2*DEX + INT reaches 530" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 150, int: 230}) ==
               %{fixed: 200, variable: 0, total: 200}
    end

    test "mid case: base 1000, dex 99, int 99" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 99, int: 99}) ==
               %{fixed: 200, variable: 201, total: 401}
    end

    test "no reduction when dex and int are 0" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 200, variable: 800, total: 1_000}
    end

    test "reads the per-level cast time array" do
      assert %{total: total} =
               CastTime.compute(definition([1_000, 2_000, 3_000]), 3, %{dex: 0, int: 0})

      assert total == 3_000
    end
  end
end
