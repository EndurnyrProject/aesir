defmodule Aesir.ZoneServer.Mmo.Mechanics.DefenseTest do
  @moduledoc """
  Classic expectations pin the physical percentage/cap branch in
  `src/map/battle.cpp:4871-4882`, magic mitigation in `src/map/battle.cpp:6106-6115`,
  and the raw soft-DEF/MDEF basis in `src/map/status.cpp:2712-2719`.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.Renewal

  test "renewal physical mitigation matches the extracted parent formula" do
    cases = [
      {200, 10, 20, 1, false, 175.609756097561},
      {200, 0, 0, 50, false, 200.0},
      {200, 500, 20, 99, false, 80.0},
      {200, -100, 20, 150, false, 240.0},
      {100, -400, 0, nil, false, 36_010.0},
      {150, 15, 5, 75, true, 140.12048192771084}
    ]

    for {damage, hard_def, soft_def, attacker_level, ignore_soft_def?, expected} <- cases do
      context = %{
        hard_def: hard_def,
        soft_def: soft_def,
        attacker_level: attacker_level,
        ignore_soft_def?: ignore_soft_def?
      }

      assert_in_delta Renewal.apply_def(damage, context), expected, 1.0e-12
    end
  end

  test "renewal magic mitigation preserves current boundaries and negative MDEF behavior" do
    cases = [
      {100, 10, 5, 86.81818181818181},
      {100, 0, 0, 100.0},
      {100, 100, 5, 50.0},
      {100, -50, 5, 185.0},
      {100, -100, 0, 9010.0},
      {100, -101, 0, -8990.0}
    ]

    for {damage, hard_mdef, soft_mdef, expected} <- cases do
      context = %{hard_mdef: hard_mdef, soft_mdef: soft_mdef}

      assert_in_delta Renewal.apply_mdef(damage, context), expected, 1.0e-12
    end
  end

  test "pre-renewal physical mitigation uses capped percentage DEF then raw soft DEF" do
    cases = [
      {250, 40, 30, 1, false, 120},
      {101, 33, 0, 50, false, 66},
      {101.9, 33, 0, 99, false, 66},
      {250, 150, 0, 150, false, -1},
      {250, -20, -5, nil, false, 299},
      {100, 0, 0, 75, false, 99},
      {100, 0, 0, 75, true, 100},
      {100, 0, 50, 75, true, 100}
    ]

    for {damage, hard_def, soft_def, attacker_level, ignore_soft_def?, expected} <- cases do
      context = %{
        hard_def: hard_def,
        soft_def: soft_def,
        attacker_level: attacker_level,
        ignore_soft_def?: ignore_soft_def?
      }

      assert PreRenewal.apply_def(damage, context) == expected
    end
  end

  test "pre-renewal magic mitigation uses integer percentage MDEF before soft MDEF" do
    cases = [
      {250, 40, 30, 120},
      {101, 33, 1, 66},
      {101.9, 33, 1, 66},
      {250, -20, 30, 270},
      {250, 150, 30, -155},
      {100, 0, 0, 100}
    ]

    for {damage, hard_mdef, soft_mdef, expected} <- cases do
      context = %{hard_mdef: hard_mdef, soft_mdef: soft_mdef}

      assert PreRenewal.apply_mdef(damage, context) == expected
    end
  end
end
