defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.FormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Sniper.Formulas

  @stats %{agi: 100, dex: 100, int: 1}

  @tag game_mode: :renewal
  test "renewal Sharpshooting scales players above base level 99 but not mobs" do
    assert Formulas.sharpshooting_ratio(5, 99) == 1800
    assert Formulas.sharpshooting_ratio(5, 150) == 2700
    assert Formulas.sharpshooting_ratio(1, 50) == 600
    assert Formulas.sharpshooting_mob_ratio(3, true) == 350
    assert Formulas.sharpshooting_mob_ratio(3, false) == 350
    assert Formulas.sharpshooting_crit_bonus() == 30
  end

  @tag game_mode: :pre_renewal
  test "classic Sharpshooting uses a separate mob lane ratio" do
    assert Formulas.sharpshooting_ratio(5, 99) == 450
    assert Formulas.sharpshooting_ratio(1, 50) == 250
    assert Formulas.sharpshooting_mob_ratio(3, true) == 420
    assert Formulas.sharpshooting_mob_ratio(3, false) == 350
    assert Formulas.sharpshooting_crit_bonus() == 20
  end

  @tag game_mode: :renewal
  test "renewal Falcon Assault scales the five Blitz hits with Steel Crow" do
    assert Formulas.falcon_assault_damage(5, 10, @stats) == 7000
    assert Formulas.falcon_assault_damage(5, 0, @stats) == 5500
    assert Formulas.falcon_assault_damage(1, 0, @stats) == 1540
  end

  @tag game_mode: :pre_renewal
  test "classic Falcon Assault uses the DEX and INT Blitz base" do
    assert Formulas.falcon_assault_damage(5, 10, @stats) == 4000
    assert Formulas.falcon_assault_damage(5, 0, @stats) == 2500
    assert Formulas.falcon_assault_damage(1, 0, @stats) == 1100
  end
end
