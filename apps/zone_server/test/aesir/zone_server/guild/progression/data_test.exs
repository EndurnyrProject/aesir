defmodule Aesir.ZoneServer.Guild.Progression.DataTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Guild.Progression.Data

  describe "exp_for_next/1" do
    test "returns the exp required to leave the given level" do
      assert Data.exp_for_next(1) == {:ok, 100_000}
      assert Data.exp_for_next(2) == {:ok, 400_000}
      assert Data.exp_for_next(49) == {:ok, 240_100_000}
    end

    test "returns :max_level at or beyond the level cap" do
      assert Data.exp_for_next(50) == :max_level
      assert Data.exp_for_next(51) == :max_level
    end
  end

  describe "max_guild_level/0" do
    test "is derived from the exp table" do
      assert Data.max_guild_level() == 50
    end
  end

  describe "level_for_exp/1" do
    test "zero exp is level 1 with no progress" do
      assert Data.level_for_exp(0) == {1, 0}
    end

    test "consuming thresholds carries the remainder" do
      assert Data.level_for_exp(100_000) == {2, 0}
      assert Data.level_for_exp(100_000 + 400_000 + 5) == {3, 5}
    end

    test "clamps at the level cap" do
      assert Data.level_for_exp(999_999_999_999) == {50, 0}
    end
  end

  describe "import overlay" do
    setup context do
      on_exit(&Data.reload/0)
      Aesir.ZoneServer.DbTestSetup.configure_root(context, "guild")
    end

    @tag :tmp_dir
    test "reload replaces an imported exp level without changing other levels", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "exp.yml"), """
      - level: 1
        exp: 100
      - level: 2
        exp: 200
      """)

      File.write!(Path.join(dir, "skill_tree.yml"), "[]\n")

      import = Path.join([dir, "..", "..", "import", "guild", "exp.yml"])
      File.mkdir_p!(Path.dirname(import))
      File.write!(import, "- level: 1\n  exp: 999\n")

      assert :ok = Data.reload()
      assert Data.exp_for_next(1) == {:ok, 999}
      assert Data.exp_for_next(2) == {:ok, 200}
    end
  end

  describe "skill_entry/1" do
    test "returns max_level and prerequisites for tree skills" do
      assert {:ok, %{max_level: 10, prerequisites: []}} = Data.skill_entry(10_004)

      assert {:ok, %{max_level: 1, prerequisites: prereqs}} = Data.skill_entry(10_013)

      assert Enum.sort(prereqs) == [
               {10_000, 1},
               {10_002, 1},
               {10_004, 5},
               {10_010, 1},
               {10_011, 1}
             ]
    end

    test "unlearnable tree skills carry max_level 0" do
      assert {:ok, %{max_level: 0}} = Data.skill_entry(10_005)
    end

    test "skills outside the tree resolve to :error" do
      assert Data.skill_entry(10_015) == :error
      assert Data.skill_entry(99) == :error
    end
  end
end
