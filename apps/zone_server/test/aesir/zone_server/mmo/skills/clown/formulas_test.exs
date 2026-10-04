defmodule Aesir.ZoneServer.Mmo.Skills.Clown.FormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Clown.Formulas

  @tag game_mode: :renewal
  test "Arrow Vulcan scales the renewal ratio by base level" do
    assert Formulas.arrow_vulcan_ratio(10, 99) == 1485
    assert Formulas.arrow_vulcan_ratio(1, 50) == 300
  end

  @tag game_mode: :pre_renewal
  test "classic Arrow Vulcan ignores base level" do
    assert Formulas.arrow_vulcan_ratio(10, 99) == 1200
    assert Formulas.arrow_vulcan_ratio(1, 50) == 300
  end

  test "Marionette freezes bounded primary-stat halves and caps gains at ninety-nine" do
    halves = Formulas.marionette_halves(%{str: 80, agi: -10, vit: 1000, int: 11, dex: 0, luk: 20})
    assert halves == %{str: 40, agi: 0, vit: 255, int: 5, dex: 0, luk: 10}

    assert Formulas.marionette_gains(halves, %{
             str: 60,
             agi: 10,
             vit: 100,
             int: 98,
             dex: 1,
             luk: 80
           }) ==
             %{str: 39, agi: 0, vit: 0, int: 1, dex: 0, luk: 10}
  end
end
