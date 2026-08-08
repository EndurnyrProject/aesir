defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IntimidateTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 86_008

  setup :setup_ets_tables

  setup do
    player = PlayerState.new(character(@player_id))
    UnitRegistry.register_unit(:player, @player_id, PlayerState, player, self())
    :ok
  end

  test "is iconless, applies, and expires" do
    assert %{icon: nil, duration: 800, no_save: true} =
             Registry.get_definition(:sc_intimidate)

    assert :ok =
             Interpreter.apply_status(:player, @player_id, :sc_intimidate,
               caster_id: @player_id,
               bypass_resistance: true
             )

    assert %StatusEntry{started_at: started_at, expires_at: expires_at} =
             StatusStorage.get_status(:player, @player_id, :sc_intimidate)

    assert expires_at - started_at == 800

    :ok =
      StatusStorage.update_status(:player, @player_id, :sc_intimidate, fn status ->
        %{status | expires_at: System.monotonic_time(:millisecond) - 1}
      end)

    assert {:noreply, state} = StatusTickManager.handle_info(:tick, %StatusTickManager.State{})
    Process.cancel_timer(state.tick_timer)

    refute StatusStorage.has_status?(:player, @player_id, :sc_intimidate)
  end

  defp character(id) do
    %Character{
      id: id,
      account_id: id,
      name: "Intimidated Rogue",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 12,
      base_level: 50,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
  end
end
