defmodule Aesir.ZoneServer.Mmo.Skills.Champion.FormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Champion.Formulas

  @tag game_mode: :renewal
  test "renewal ratios scale with base level above 99 only" do
    assert Formulas.palm_ratio(5, 100, 99) == 800
    assert Formulas.palm_ratio(5, 100, 150) == div(800 * 150, 100)
    assert Formulas.glacier_ratio(5, 99) == 1_250
    assert Formulas.chain_crush_ratio(10, 150) == 3_000
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal ratios ignore base level and STR" do
    assert Formulas.palm_ratio(5, 100, 99) == 700
    assert Formulas.glacier_ratio(1, 99) == 140
    assert Formulas.glacier_ratio(5, 99) == 540
    assert Formulas.chain_crush_ratio(10, 99) == 1_400
  end

  test "Chain Crush shows one hit per two levels, rounded up" do
    assert Enum.map(1..10, &Formulas.chain_crush_display_hits/1) == [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
  end

  test "Glacier Fist immobilise chance and duration" do
    assert Formulas.glacier_ankle_chance(1) == 20
    assert Formulas.glacier_ankle_chance(5) == 60

    # AGI shortens the base, a caster-level floor bounds it, bosses get a fifth.
    assert Formulas.glacier_ankle_duration(5, 100, false, 1) == 5_000
    assert Formulas.glacier_ankle_duration(5, 200, false, 99) == 15 * 199
    assert Formulas.glacier_ankle_duration(5, 0, true, 1) == 2_000
    assert Formulas.glacier_ankle_duration(5, 0, true, 99) == 15 * 199
  end

  test "Palm Strike lands one second plus an attack motion later" do
    assert Formulas.palm_impact_delay(350) == 1_350
  end
end
