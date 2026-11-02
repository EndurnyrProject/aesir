defmodule Aesir.ZoneServer.Unit.Player.Handlers.IntravisionRefreshTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.UnitSpawn
  alias Aesir.Net.UnitStateChange
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.VisibilityHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    character = %Character{
      id: 7_708,
      account_id: 7_708,
      name: "Intravision",
      class: 0,
      base_level: 1,
      job_level: 1,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 40,
      sp: 11,
      last_map: "prontera",
      last_x: 100,
      last_y: 100
    }

    player = PlayerState.new(character)
    concealed = PlayerState.new(%{character | id: 7_709, account_id: 7_709, name: "Hidden"})
    player = %{player | visible_players: MapSet.new([concealed.character_id])}
    :ok = UnitRegistry.register_player(player, self())
    :ok = UnitRegistry.register_player(concealed, self())
    :ok = SpatialIndex.update_visibility(player.character_id, concealed.character_id, true)

    :ok =
      StatusStorage.apply_status(:player, concealed.character_id, :sc_hiding, duration: 30_000)

    %{state: %SessionState{game_state: player, connection_pid: self()}, concealed: concealed}
  end

  test "a stationary observer refreshes a newly entered spatially visible player", %{
    state: state,
    concealed: concealed
  } do
    id = state.game_state.character_id
    target_id = concealed.character_id
    :ok = SpatialIndex.update_visibility(id, target_id, true)
    state = %{state | game_state: %{state.game_state | visible_players: MapSet.new()}}

    assert {:ok, events} =
             Interpreter.apply_status_with_events(:player, id, :sc_intravision,
               duration: 30_000,
               owner_refresh: :defer
             )

    StatusManager.refresh_events(state, events)

    assert_receive {:send, :world,
                    {:unit_state_change, %UnitStateChange{unit_id: ^target_id, effect_state: 0}}}
  end

  test "intravision refresh is observer-only for existing and entering concealed units", %{
    state: state,
    concealed: concealed
  } do
    id = state.game_state.character_id
    target_id = concealed.character_id
    refute PlayerState.intravision?(state.game_state)

    assert {:ok, events} =
             Interpreter.apply_status_with_events(:player, id, :sc_intravision,
               val1: 0,
               duration: 30_000,
               owner_refresh: :defer
             )

    applied = StatusManager.refresh_events(state, events)
    assert PlayerState.intravision?(applied.game_state)

    assert_receive {:send, :world,
                    {:unit_state_change, %UnitStateChange{unit_id: ^target_id, effect_state: 0}}}

    assert StatusStorage.has_status?(:player, target_id, :sc_hiding)

    assert {:noreply, _} = VisibilityHandler.entered_view(target_id, applied)
    assert_receive {:send, :world, {:unit_spawn, %UnitSpawn{gid: ^target_id, effect_state: 0}}}
  end

  test "refresh skips vanished units, the observer and GM-invisible targets", %{
    state: state,
    concealed: concealed
  } do
    hidden_gm = %{concealed | option: Option.id(:invisible)}
    :ok = UnitRegistry.update_unit_state(:player, concealed.character_id, hidden_gm)
    :ok = StatusStorage.apply_status(:player, state.game_state.character_id, :sc_hiding)

    observer = %{
      state.game_state
      | visible_players:
          MapSet.new([concealed.character_id, state.game_state.character_id, 99_998])
    }

    assert VisibilityHandler.refresh_concealment(%{state | game_state: observer})
    refute_receive {:send, :world, {:unit_state_change, _}}, 0
  end

  test "equipment and timed sight overlap survives either source ending", %{
    state: state,
    concealed: concealed
  } do
    id = state.game_state.character_id
    target_id = concealed.character_id
    player = state.game_state

    gear = [
      %InventoryItem{
        id: 1,
        nameid: 2221,
        card0: 4198,
        equip: EquipLocation.location_bit(:head_top)
      }
    ]

    equipped = %{player | stats: Calculator.calculate_stats(player.stats, id, gear)}
    equipped_state = StateCommit.commit(state, equipped)

    assert_receive {:send, :world,
                    {:unit_state_change, %UnitStateChange{unit_id: ^target_id, effect_state: 0}}}

    assert {:ok, events} =
             Interpreter.apply_status_with_events(:player, id, :sc_intravision,
               duration: 30_000,
               owner_refresh: :defer
             )

    both = StatusManager.refresh_events(equipped_state, events)
    refute_receive {:send, :world, {:unit_state_change, _}}, 0

    player = both.game_state
    without_equipment = %{player | stats: Calculator.calculate_stats(player.stats, id, [])}
    status_only = StateCommit.commit(both, without_equipment)
    assert PlayerState.intravision?(status_only.game_state)
    refute_receive {:send, :world, {:unit_state_change, _}}, 0

    {:ok, removed} =
      Interpreter.remove_status_with_events(:player, id, :sc_intravision, owner_refresh: :defer)

    ended = StatusManager.refresh_events(status_only, removed)
    refute PlayerState.intravision?(ended.game_state)

    assert_receive {:send, :world,
                    {:unit_state_change, %UnitStateChange{unit_id: ^target_id, effect_state: 2}}}

    player = ended.game_state
    equipped = %{player | stats: Calculator.calculate_stats(player.stats, id, gear)}
    equipped_state = StateCommit.commit(ended, equipped)
    assert_receive {:send, :world, {:unit_state_change, %UnitStateChange{effect_state: 0}}}

    {:ok, events} =
      Interpreter.apply_status_with_events(:player, id, :sc_intravision,
        duration: 30_000,
        owner_refresh: :defer
      )

    both = StatusManager.refresh_events(equipped_state, events)

    {:ok, removed} =
      Interpreter.remove_status_with_events(:player, id, :sc_intravision, owner_refresh: :defer)

    equipment_only = StatusManager.refresh_events(both, removed)
    assert PlayerState.intravision?(equipment_only.game_state)
    refute_receive {:send, :world, {:unit_state_change, _}}, 0

    player = equipment_only.game_state

    final =
      StateCommit.commit(
        equipment_only,
        %{player | stats: Calculator.calculate_stats(player.stats, id, [])}
      )

    refute PlayerState.intravision?(final.game_state)
    assert_receive {:send, :world, {:unit_state_change, %UnitStateChange{effect_state: 2}}}
  end
end
