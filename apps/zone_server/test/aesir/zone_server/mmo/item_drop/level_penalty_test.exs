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

  setup do
    :persistent_term.put(LevelPenalty, @table)
    on_exit(fn -> :persistent_term.erase(LevelPenalty) end)
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

  test "drop/2 works through reload/0 + the priv/db/level_penalty.yml file" do
    :ok = LevelPenalty.reload()

    assert LevelPenalty.drop(116, 100) == 50
    assert LevelPenalty.drop(105, 100) == 90
    assert LevelPenalty.drop(100, 100) == 100
  end
end
