defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHitRateTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "HIT-rate statuses run after equipment rates with signed contribution truncation" do
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

    assert reduced.combat_stats.hit ==
             baseline.combat_stats.hit - div(baseline.combat_stats.hit * 20, 100)

    stacked =
      %{reduced | modifiers: %{reduced.modifiers | equipment: %{hit_rate: 30}}}
      |> Calculator.calculate_combat_stats()

    equipment_hit = div(baseline.combat_stats.hit * 130, 100)
    assert stacked.combat_stats.hit == equipment_hit - div(equipment_hit * 20, 100)

    assert :ok =
             Interpreter.apply_status(:player, 17, :sc_inchitrate, val1: 3, duration: 30_000)

    assert :ok = Interpreter.apply_status(:player, 17, :sc_inchit, val1: 7, duration: 30_000)

    boosted =
      reduced
      |> Calculator.apply_status_effects(17)
      |> then(&%{&1 | modifiers: %{&1.modifiers | equipment: %{hit_rate: 30}}})
      |> Calculator.calculate_combat_stats()

    with_flat_bonus = equipment_hit + 7

    assert boosted.combat_stats.hit ==
             with_flat_bonus + div(with_flat_bonus * 3, 100)

    assert :ok = StatusStorage.apply_status(:player, 17, :sc_blind, duration: 30_000)

    blinded =
      boosted
      |> Calculator.apply_status_effects(17)
      |> Calculator.calculate_combat_stats()

    assert blinded.combat_stats.hit ==
             boosted.combat_stats.hit - div(boosted.combat_stats.hit * 25, 100)

    assert blinded.combat_stats.flee ==
             boosted.combat_stats.flee - div(boosted.combat_stats.flee * 25, 100)

    assert Registry.get_definition(:sc_tarotcard).icon == :tarotcard
  end
end
