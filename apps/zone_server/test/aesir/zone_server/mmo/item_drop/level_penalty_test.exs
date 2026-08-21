defmodule Aesir.ZoneServer.Mmo.ItemDrop.LevelPenaltyTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty

  @table %{
    -16 => 50,
    -13 => 60,
    -10 => 70,
    -7 => 80,
    -4 => 90,
    4 => 90,
    7 => 80,
    10 => 70,
    13 => 60,
    16 => 50
  }

  @exp_table %{
    -30 => 70,
    -20 => 90,
    20 => 90,
    30 => 70
  }

  @mvp_drop_table %{
    -10 => 60,
    10 => 60
  }

  @mvp_exp_table %{
    -25 => 80,
    25 => 80
  }

  setup do
    :persistent_term.put(LevelPenalty, @table)
    :persistent_term.put({LevelPenalty, :exp}, @exp_table)
    :persistent_term.put({LevelPenalty, :mvp_drop}, @mvp_drop_table)
    :persistent_term.put({LevelPenalty, :mvp_exp}, @mvp_exp_table)

    on_exit(fn ->
      :persistent_term.erase(LevelPenalty)
      :persistent_term.erase({LevelPenalty, :exp})
      :persistent_term.erase({LevelPenalty, :mvp_drop})
      :persistent_term.erase({LevelPenalty, :mvp_exp})
    end)

    :ok
  end

  test "drop/2 returns the rate on an exact breakpoint" do
    assert LevelPenalty.drop(104, 100) == 90
    assert LevelPenalty.drop(116, 100) == 50
  end

  test "drop/2 carries the breakpoint forward toward zero for unlisted diffs" do
    assert LevelPenalty.drop(105, 100) == 90
    assert LevelPenalty.drop(108, 100) == 80
    assert LevelPenalty.drop(117, 100) == 50
    assert LevelPenalty.drop(95, 100) == 90
    assert LevelPenalty.drop(83, 100) == 50
  end

  test "drop/2 returns 100 inside the no-penalty band around zero" do
    assert LevelPenalty.drop(103, 100) == 100
    assert LevelPenalty.drop(100, 100) == 100
  end

  test "drop/2 works through reload/0 + the priv/db/re/level_penalty.yml file" do
    :ok = LevelPenalty.reload()

    assert LevelPenalty.drop(116, 100) == 50
    assert LevelPenalty.drop(105, 100) == 90
    assert LevelPenalty.drop(100, 100) == 100
  end

  test "exp/2 returns the rate on an exact breakpoint" do
    assert LevelPenalty.exp(120, 100) == 90
    assert LevelPenalty.exp(130, 100) == 70
  end

  test "exp/2 carries the breakpoint forward toward zero for unlisted diffs" do
    assert LevelPenalty.exp(125, 100) == 90
    assert LevelPenalty.exp(140, 100) == 70
    assert LevelPenalty.exp(75, 100) == 90
    assert LevelPenalty.exp(65, 100) == 70
  end

  test "exp/2 returns 100 inside the no-penalty band around zero" do
    assert LevelPenalty.exp(115, 100) == 100
    assert LevelPenalty.exp(100, 100) == 100
  end

  test "exp/2 works through reload/0 + the priv/db/re/level_penalty_exp.yml file" do
    :ok = LevelPenalty.reload()

    assert LevelPenalty.exp(100, 100) == 100
  end

  test "mvp_drop/2 returns 100 at zero level difference" do
    assert LevelPenalty.mvp_drop(100, 100) == 100
  end

  test "mvp_drop/2 carries the breakpoint forward toward zero for unlisted diffs" do
    assert LevelPenalty.mvp_drop(115, 100) == 60
    assert LevelPenalty.mvp_drop(85, 100) == 60
  end

  test "mvp_drop/2 works through reload/0 + the priv/db/re/level_penalty_mvp_drop.yml file" do
    :ok = LevelPenalty.reload()

    assert LevelPenalty.mvp_drop(100, 100) == 100
  end

  test "mvp_exp/2 returns 100 at zero level difference" do
    assert LevelPenalty.mvp_exp(100, 100) == 100
  end

  test "mvp_exp/2 carries the breakpoint forward toward zero for unlisted diffs" do
    assert LevelPenalty.mvp_exp(130, 100) == 80
    assert LevelPenalty.mvp_exp(70, 100) == 80
  end

  test "mvp_exp/2 works through reload/0 + the priv/db/re/level_penalty_mvp_exp.yml file" do
    :ok = LevelPenalty.reload()

    assert LevelPenalty.mvp_exp(100, 100) == 100
  end

  # The shipped MVP tables are empty, so no value assertion can distinguish a
  # reloaded table from one that was never refreshed. Seeding a sentinel
  # breakpoint first and asserting it is gone afterwards proves reload/0 actually
  # replaced each table, which asserting 100 at zero difference does not.
  test "reload/0 refreshes all four tables from their priv/db files" do
    sentinel = %{10 => 42}

    :persistent_term.put(LevelPenalty, sentinel)
    :persistent_term.put({LevelPenalty, :exp}, sentinel)
    :persistent_term.put({LevelPenalty, :mvp_drop}, sentinel)
    :persistent_term.put({LevelPenalty, :mvp_exp}, sentinel)

    :ok = LevelPenalty.reload()

    assert LevelPenalty.drop(116, 100) == 50
    assert LevelPenalty.exp(116, 100) == 40

    refute LevelPenalty.mvp_drop(110, 100) == 42
    refute LevelPenalty.mvp_exp(110, 100) == 42
    assert LevelPenalty.mvp_drop(110, 100) == 100
    assert LevelPenalty.mvp_exp(110, 100) == 100
  end
end
