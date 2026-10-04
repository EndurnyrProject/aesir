defmodule Aesir.ZoneServer.Mmo.Skills.Clown.FormulasTest do
  use ExUnit.Case, async: true

  alias Aesir.TestEtsSetup
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
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

  test "Tarot success includes the eight-percent-per-level boundary" do
    assert Formulas.tarot_success?(5, fn 100 -> 40 end)
    refute Formulas.tarot_success?(5, fn 100 -> 41 end)
    assert Formulas.tarot_success?(1, fn 100 -> 8 end)
    refute Formulas.tarot_success?(1, fn 100 -> 9 end)
  end

  test "a performance box must be wall-free on a known map" do
    TestEtsSetup.setup_ets_tables(%{})
    map = MapData.new("box_test", 20, 20)
    :ets.insert(EtsTable.table_for(:map_cache), {"box_test", map})
    assert Formulas.box_wall_free?("box_test", 10, 10, 4)
    blocked = MapData.set_cell(map, 14, 14, GatType.wall())
    :ets.insert(EtsTable.table_for(:map_cache), {"box_test", blocked})
    refute Formulas.box_wall_free?("box_test", 10, 10, 4)
    refute Formulas.box_wall_free?("unknown_box", 10, 10, 4)
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
