defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatusManagerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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
      id: player_id,
      account_id: 100,
      name: "Status Tester",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "M",
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

    game_state = PlayerState.new(character)
    state = %{connection_pid: self(), game_state: %{game_state | walk_speed: 150}}

    {:ok, state: state}
  end

  describe "walk-speed recalc on speed-flagged statuses" do
    test "applying Decrease AGI slows the player and broadcasts the new speed", %{state: state} do
      {:reply, :ok, applied} =
        StatusManager.handle_apply_status(:sc_decreaseagi, [val1: 1], state)

      assert applied.game_state.walk_speed == 187
      assert_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0, value: 187}}}
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

      assert applied.game_state.walk_speed == 112
      assert_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0, value: 112}}}
    end

    test "applying Curse slows the player by rAthena's flat 300 rate", %{state: state} do
      {:reply, :ok, applied} = StatusManager.handle_apply_status(:sc_curse, [], state)

      assert applied.game_state.walk_speed == 600
      assert_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0, value: 600}}}
    end

    test "applying Cloaking (level 3) applies the not-against-wall slow", %{state: state} do
      {:reply, :ok, applied} =
        StatusManager.handle_apply_status(:sc_cloaking, [val1: 3], state)

      assert applied.game_state.walk_speed == 181
      assert_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0, value: 181}}}
    end
  end

  describe "walk_speed_for/1 with equipment movement speed" do
    test "an equipment bonus speeds the player up (positive = faster)", %{state: state} do
      stats = with_equipment_speed(state.game_state.stats, 25)

      assert StatusManager.walk_speed_for(stats) == 112
    end

    test "no equipment bonus leaves the base speed", %{state: state} do
      assert StatusManager.walk_speed_for(state.game_state.stats) == 150
    end

    test "the equipment bonus offsets a status slow", %{state: state} do
      stats =
        state.game_state.stats
        |> with_equipment_speed(25)
        |> put_in([Access.key!(:modifiers), Access.key!(:status_effects)], %{movement_speed: 25})

      assert StatusManager.walk_speed_for(stats) == 150
    end

    defp with_equipment_speed(stats, bonus) do
      put_in(stats, [Access.key!(:modifiers), Access.key!(:equipment)], %{movement_speed: bonus})
    end
  end

  describe "statuses without a :speed flag" do
    test "leave walk_speed at 150 and emit no speed ParamChange", %{state: state} do
      {:reply, :ok, applied} = StatusManager.handle_apply_status(:sc_poison, [val1: 5], state)

      assert applied.game_state.walk_speed == 150
      refute_receive {:send, :gameplay, {:param_change, %ParamChange{var_id: 0}}}
    end
  end

  test "publishes status-driven maxima and clamped current resources", %{state: state} do
    game_state = %{state.game_state | party_id: 7}

    recalculated =
      game_state.stats
      |> put_in([Access.key!(:current_state), Access.key!(:hp)], 700)
      |> put_in([Access.key!(:current_state), Access.key!(:sp)], 250)
      |> put_in([Access.key!(:current_state), Access.key!(:ap)], 20)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_hp)], 700)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_sp)], 250)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_ap)], 20)

    expect(Stats, :calculate_stats, fn _stats, id when id == game_state.character_id ->
      recalculated
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, _id, _game_state -> :ok end)

    expect(Manager, :sync_member, fn 7, char_id, member ->
      assert char_id == game_state.character_id

      assert member == %Member{
               char_id: game_state.character_id,
               name: "Status Tester",
               job_id: recalculated.progression.job_id,
               base_level: recalculated.progression.base_level,
               hp: 700,
               max_hp: 700,
               sp: 250,
               max_sp: 250,
               ap: 20,
               max_ap: 20,
               online: true,
               map_name: "prontera"
             }

      {:ok, %{}}
    end)

    assert %{game_state: %{stats: ^recalculated}} =
             StatusManager.recalculate_after_status_change(%{state | game_state: game_state})
  end
end
