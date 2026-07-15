defmodule Aesir.ZoneServer.Unit.Player.Handlers.MapLoadHandlerTest do
  @moduledoc """
  Covers the owner-directed self sync on initial map load: the spawn and
  visibility flows only carry a unit's sprite state and status icons to other
  observers, so the map-load ack must tell the owner about state restored at
  login (the cart re-mounted by `load_on_spawn`, persisted statuses).
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.QuestEntry
  alias Aesir.Net.QuestList
  alias Aesir.Net.StatusChange
  alias Aesir.Net.UnitStateChange
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.MapLoadHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestLog

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @char_id 7100

  setup do
    Mimic.copy(SkillUnitManager)

    stub(SkillUnitManager, :snapshot_for, fn _observer_id, _map, _x, _y, _range ->
      MapSet.new()
    end)

    Registry.load_definitions()
    :ok
  end

  defp character do
    %Character{
      id: @char_id,
      account_id: 2000,
      name: "Merchy",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 50,
      job_level: 50,
      class: 0,
      hp: 800,
      sp: 300
    }
  end

  defp session_state do
    %{
      game_state: PlayerState.new(character()),
      connection_pid: self()
    }
  end

  test "the initial load sends the owner their own restored sprite state" do
    :ok = StatusStorage.apply_status(:player, @char_id, :sc_push_cart, val1: 5, val2: 1)

    {:noreply, _state} = MapLoadHandler.handle_map_loaded(session_state())

    cart1_bit = Option.id(:cart1)

    assert_received {:send, _channel,
                     {:unit_state_change,
                      %UnitStateChange{unit_id: @char_id, effect_state: ^cart1_bit}}}
  end

  test "the initial load backfills the owner's own status icons" do
    :ok = StatusStorage.apply_status(:player, @char_id, :sc_blessing, val1: 10, duration: 60_000)

    {:noreply, _state} = MapLoadHandler.handle_map_loaded(session_state())

    assert_received {:send, _channel,
                     {:status_change, %StatusChange{unit_id: @char_id, on: true}}}
  end

  test "a player with no statuses gets an all-zero self state and no icons" do
    {:noreply, _state} = MapLoadHandler.handle_map_loaded(session_state())

    assert_received {:send, _channel,
                     {:unit_state_change, %UnitStateChange{unit_id: @char_id, effect_state: 0}}}

    refute_received {:send, _channel, {:status_change, _}}
  end

  test "the initial load sends the owner their loaded quest log" do
    state = session_state()

    quest_log = %{7393 => %QuestLog.Entry{state: :active, counts: [], deadline: nil}}
    game_state = %{state.game_state | quest_log: quest_log}

    {:noreply, _state} = MapLoadHandler.handle_map_loaded(%{state | game_state: game_state})

    assert_received {:send, _channel,
                     {:quest_list, %QuestList{quests: [%QuestEntry{quest_id: 7393, state: 1}]}}}
  end

  test "a quest-less character gets an empty quest list" do
    {:noreply, _state} = MapLoadHandler.handle_map_loaded(session_state())

    assert_received {:send, _channel, {:quest_list, %QuestList{quests: []}}}
  end

  test "the initial load replaces visible skill units with the manager snapshot" do
    expect(SkillUnitManager, :snapshot_for, fn @char_id, "prontera", 150, 150, range ->
      assert is_integer(range)
      MapSet.new([11, 12])
    end)

    {:noreply, state} = MapLoadHandler.handle_map_loaded(session_state())

    assert state.game_state.visible_skill_units == MapSet.new([11, 12])
  end
end
