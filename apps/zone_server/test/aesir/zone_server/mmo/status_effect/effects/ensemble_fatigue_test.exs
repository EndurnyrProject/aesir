defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnsembleFatigueTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 86_001

  setup :setup_ets_tables

  setup do
    player = PlayerState.new(character(@player_id))
    UnitRegistry.register_unit(:player, @player_id, PlayerState, player, self())
    :ok
  end

  test "blocks every skill while active" do
    assert :ok = apply_fatigue()

    for skill_id <- [1, 143, 999_999] do
      refute Interpreter.can_use_skill?(:player, @player_id, skill_id)
    end
  end

  test "measurably increases walk and attack intervals" do
    {:ok, {_module, player, _pid}} = UnitRegistry.get_unit(:player, @player_id)
    baseline = Stats.calculate_stats(player.stats, @player_id)

    assert :ok = apply_fatigue()
    fatigued = Stats.calculate_stats(player.stats, @player_id)

    assert StatusManager.walk_speed_for(fatigued) > StatusManager.walk_speed_for(baseline)

    assert AttackSpeed.calculate_delay_from_stats(fatigued) >
             AttackSpeed.calculate_delay_from_stats(baseline)
  end

  test "expires after ten seconds" do
    assert :ok = apply_fatigue()

    assert %StatusEntry{started_at: started_at, expires_at: expires_at} =
             StatusStorage.get_status(:player, @player_id, :sc_ensemblefatigue)

    assert expires_at - started_at == 10_000

    :ok =
      StatusStorage.update_status(:player, @player_id, :sc_ensemblefatigue, fn status ->
        %{status | expires_at: System.monotonic_time(:millisecond) - 1}
      end)

    assert {:noreply, state} = StatusTickManager.handle_info(:tick, %StatusTickManager.State{})
    Process.cancel_timer(state.tick_timer)

    refute StatusStorage.has_status?(:player, @player_id, :sc_ensemblefatigue)
  end

  test "is removed on death" do
    assert :ok = apply_fatigue()
    assert :ok = Interpreter.remove_on_death(:player, @player_id)

    refute StatusStorage.has_status?(:player, @player_id, :sc_ensemblefatigue)
  end

  test "cannot be cleared early by Dispell" do
    assert :ok = apply_fatigue()
    assert :ok = Dispel.dispel({:player, @player_id})

    assert StatusStorage.has_status?(:player, @player_id, :sc_ensemblefatigue)
  end

  defp apply_fatigue do
    Interpreter.apply_status(:player, @player_id, :sc_ensemblefatigue,
      caster_id: @player_id,
      bypass_resistance: true
    )
  end

  defp character(id) do
    %Character{
      id: id,
      account_id: id,
      name: "Fatigued Performer",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 19,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 30,
      vit: 10,
      int: 10,
      dex: 30,
      luk: 10
    }
  end
end
