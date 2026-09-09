defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.FormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Formulas

  @tag game_mode: :renewal
  test "calculates Renewal Blitz Beat base damage with integer stat steps" do
    for {blitz_level, steel_crow_level, agi, dex, expected} <- [
          {0, 0, 0, 0, 0},
          {1, 0, 1, 9, 20},
          {5, 10, 99, 99, 276}
        ] do
      assert Formulas.blitz_beat_base_damage(blitz_level, steel_crow_level, %{
               agi: agi,
               dex: dex,
               int: 0
             }) ==
               expected
    end
  end

  @tag game_mode: :pre_renewal
  test "classic Blitz Beat base damage reads DEX, INT, and Steel Crow, never the level" do
    assert Formulas.blitz_beat_base_damage(5, 0, %{agi: 99, dex: 0, int: 0}) == 80
    assert Formulas.blitz_beat_base_damage(1, 10, %{agi: 0, dex: 100, int: 50}) == 210
  end

  test "calculates automatic Blitz Beat chance on the thousand-point roll scale" do
    for {luk, expected} <- [{0, 1}, {1, 4}, {3, 11}, {99, 331}] do
      assert Formulas.auto_blitz_chance(luk) == expected
    end
  end

  test "caps automatic Blitz Beat level by Hunter job level" do
    for {learned_level, job_level, expected} <- [
          {0, 0, 0},
          {5, 0, 0},
          {5, 1, 1},
          {5, 10, 1},
          {5, 11, 2},
          {5, 50, 5},
          {3, 50, 3}
        ] do
      assert Formulas.auto_blitz_effective_level(learned_level, job_level) == expected
    end
  end
end
