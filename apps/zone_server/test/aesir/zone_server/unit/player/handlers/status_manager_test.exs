defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatusManagerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(UnitRegistry)
    Mimic.copy(Resistance)
    stub(Resistance, :roll_success, fn _success_rate -> true end)

    player_id = :rand.uniform(100_000)

    stub(UnitRegistry, :get_unit_info, fn _unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{level: 50, base_level: 50, str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10}
       }}
    end)

    character = %Character{
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 50,
      job_level: 30,
      hp: 800,
      sp: 300,
      class: 0
    }

    state = %{
      connection_pid: self(),
      game_state: %{
        character_id: player_id,
        stats: Stats.from_character(character),
        walk_speed: 150
      }
    }

    {:ok, state: state}
  end

  describe "walk-speed recalc on speed-flagged statuses" do
    test "applying Decrease AGI slows the player and broadcasts the new speed", %{state: state} do
      {:reply, :ok, applied} =
        StatusManager.handle_apply_status(:sc_decreaseagi, [val1: 1], state)

      assert applied.game_state.walk_speed == 168
      assert_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0, value: 168}}}
    end

    test "removing Decrease AGI restores the base speed of 150", %{state: state} do
      {:reply, :ok, applied} =
        StatusManager.handle_apply_status(:sc_decreaseagi, [val1: 1], state)

      {:reply, :ok, removed} = StatusManager.handle_remove_status(:sc_decreaseagi, applied)

      assert removed.game_state.walk_speed == 150
      assert_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0, value: 150}}}
    end

    test "applying Increase AGI speeds the player up", %{state: state} do
      {:reply, :ok, applied} =
        StatusManager.handle_apply_status(:sc_increaseagi, [val1: 1, val2: 6], state)

      assert applied.game_state.walk_speed == 132
      assert_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0, value: 132}}}
    end
  end

  describe "statuses without a :speed flag" do
    test "leave walk_speed at 150 and emit no speed ParamChange", %{state: state} do
      {:reply, :ok, applied} = StatusManager.handle_apply_status(:sc_poison, [val1: 5], state)

      assert applied.game_state.walk_speed == 150
      refute_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0}}}
    end
  end
end
