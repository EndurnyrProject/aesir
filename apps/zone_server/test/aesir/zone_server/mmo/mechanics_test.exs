defmodule Aesir.ZoneServer.Mmo.MechanicsTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Mechanics

  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime
  alias Aesir.ZoneServer.Mmo.Mechanics.Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.Elements
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas
  alias Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas
  alias Aesir.ZoneServer.Mmo.Mechanics.Sizes
  alias Aesir.ZoneServer.Mmo.Mechanics.StatCost

  setup :set_mimic_private
  setup :verify_on_exit!

  test "selects every formula family for each game mode" do
    for {mode, implementations} <- [
          renewal: [
            PlayerFormulas.Renewal,
            MobFormulas.Renewal,
            CastTime.Renewal,
            StatCost.Renewal,
            Defense.Renewal,
            Elements.Renewal,
            Sizes.Renewal
          ],
          pre_renewal: [
            PlayerFormulas.PreRenewal,
            MobFormulas.PreRenewal,
            CastTime.PreRenewal,
            StatCost.PreRenewal,
            Defense.PreRenewal,
            Elements.PreRenewal,
            Sizes.PreRenewal
          ]
        ] do
      stub(GameMode, :mode, fn -> mode end)

      [
        player_formulas,
        mob_formulas,
        cast_time,
        stat_cost,
        defense,
        elements,
        sizes
      ] = implementations

      assert Mechanics.player_formulas() == player_formulas
      assert Mechanics.mob_formulas() == mob_formulas
      assert Mechanics.cast_time() == cast_time
      assert Mechanics.stat_cost() == stat_cost
      assert Mechanics.defense() == defense
      assert Mechanics.elements() == elements
      assert Mechanics.sizes() == sizes
    end
  end
end
