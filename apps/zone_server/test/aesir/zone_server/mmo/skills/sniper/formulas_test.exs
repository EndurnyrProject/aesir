defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.FormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Sniper.Formulas

  @stats %{agi: 100, dex: 100, int: 1}

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
