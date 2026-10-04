defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHitRateTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "a HIT-rate status reduces the calculated HIT and adds to equipment rates" do
    player =
      PlayerState.new(%Character{
        id: 17,
        account_id: 17,
        name: "HIT holder",
        class: 19,
        base_level: 50,
        job_level: 50,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        str: 10,
        agi: 10,
        vit: 0,
        int: 10,
        dex: 30,
        luk: 0
      })

    :ok = UnitRegistry.register_player(player, self())
    baseline = Calculator.calculate_stats(player.stats, 17)

    assert :ok =
             Interpreter.apply_status(:player, 17, :sc_inchitrate,
               caster_id: 17,
               val1: -20,
               duration: 30_000
             )

    reduced = Calculator.calculate_stats(player.stats, 17)
    assert reduced.combat_stats.hit == div(baseline.combat_stats.hit * 80, 100)

    stacked =
      %{reduced | modifiers: %{reduced.modifiers | equipment: %{hit_rate: 30}}}
      |> Calculator.calculate_combat_stats()

    assert stacked.combat_stats.hit == div(baseline.combat_stats.hit * 110, 100)
    assert Registry.get_definition(:sc_tarotcard).icon == :tarotcard
  end
end
