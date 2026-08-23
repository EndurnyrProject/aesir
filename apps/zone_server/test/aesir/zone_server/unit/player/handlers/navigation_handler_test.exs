defmodule Aesir.ZoneServer.Unit.Player.Handlers.NavigationHandlerTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.NavigateTo
  alias Aesir.Net.NavigationCancel
  alias Aesir.Net.NavigationCoordinate
  alias Aesir.Net.NavigationEnded
  alias Aesir.Net.NavigationFailed
  alias Aesir.Net.NavigationRequest
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Navigation.Portal
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Route.Leg
  alias Aesir.ZoneServer.Navigation.Session
  alias Aesir.ZoneServer.Unit.Player.Handlers.NavigationHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  setup :setup_ets_tables

  setup do
    Enum.each(["prontera", "geffen", "morocc"], fn map_name ->
      :ets.insert(EtsTable.table_for(:map_cache), {map_name, MapData.new(map_name, 20, 20)})
    end)

    :persistent_term.put(PortalGraph, test_graph())
    on_exit(fn -> :persistent_term.erase(PortalGraph) end)
    :ok
  end

  test "starts routing asynchronously and retains the producer options" do
    state = session_state()

    assert {:noreply, started} =
             NavigationHandler.start(state, {:coord, "prontera", 2, 1},
               flag: 73,
               hide_window: true
             )

    assert %Session{
             ref: ref,
             target: {:coord, "prontera", 2, 1},
             route: nil,
             leg: 0,
             flag: 73,
             hide_window: true
           } = started.navigation

    assert_receive {:navigation, {:routed, ^ref, {:ok, %Route{}}}}
  end

  test "accepts the matching route, sends it, and stores it" do
    route = route()
    ref = make_ref()
    navigation = %Session{ref: ref, target: {:monster, 1_002}, flag: 73, hide_window: true}
    state = %{session_state() | navigation: navigation}

    assert {:noreply, updated} = NavigationHandler.handle_routed(state, ref, {:ok, route})
    assert %Session{route: ^route, leg: 0} = updated.navigation

    assert_received {:send, :world,
                     {:navigate_to, %NavigateTo{flag: 73, hide_window: true, monster_id: 1_002}}}
  end

  test "discards a stale routing result without sending or changing state" do
    active_ref = make_ref()
    stale_ref = make_ref()
    state = %{session_state() | navigation: %Session{ref: active_ref, target: {:map, "geffen"}}}

    assert {:noreply, ^state} = NavigationHandler.handle_routed(state, stale_ref, {:ok, route()})
    refute_received {:send, _channel, _message}
  end

  test "reports a matching routing failure and clears the navigation" do
    ref = make_ref()
    state = %{session_state() | navigation: %Session{ref: ref, target: {:map, "missing"}}}

    assert {:noreply, updated} =
             NavigationHandler.handle_routed(state, ref, {:error, :unresolved})

    assert updated.navigation == nil

    assert_received {:send, :world,
                     {:navigation_failed,
                      %NavigationFailed{reason: :NAVIGATION_FAILURE_REASON_UNRESOLVED}}}
  end

  test "cancels an active navigation and reports the end reason" do
    state = %{session_state() | navigation: %Session{ref: make_ref(), target: {:map, "geffen"}}}

    assert {:noreply, updated} = NavigationHandler.cancel(state, :cancelled)
    assert updated.navigation == nil

    assert_received {:send, :world,
                     {:navigation_ended,
                      %NavigationEnded{reason: :NAVIGATION_END_REASON_CANCELLED}}}
  end

  test "cancelling without an active navigation is a no-op" do
    state = session_state()

    assert {:noreply, ^state} = NavigationHandler.cancel(state, :cancelled)
    refute_received {:send, _channel, _message}
  end

  test "routes a client coordinate request with its display options" do
    request = %NavigationRequest{
      target: {:coord, %NavigationCoordinate{map: "prontera", x: 2, y: 1}},
      flag: 91,
      hide_window: true
    }

    assert {:noreply, started} = PacketHandler.handle_message(request, session_state())

    assert %Session{
             ref: ref,
             target: {:coord, "prontera", 2, 1},
             flag: 91,
             hide_window: true
           } = started.navigation

    assert_receive {:navigation, {:routed, ^ref, {:ok, %Route{}}}}
  end

  test "routes a client cancellation through the navigation handler" do
    state = %{session_state() | navigation: %Session{ref: make_ref(), target: {:map, "geffen"}}}

    assert {:noreply, updated} = PacketHandler.handle_message(%NavigationCancel{}, state)
    assert updated.navigation == nil
    assert_received {:send, :world, {:navigation_ended, %NavigationEnded{}}}
  end

  test "PlayerSession routes navigation casts through the handler shell" do
    assert {:noreply, started} =
             PlayerSession.handle_cast(
               {:navigation, {:start, {:coord, "prontera", 2, 1}, [flag: 37]}},
               session_state()
             )

    assert %Session{ref: ref, flag: 37} = started.navigation
    assert_receive {:navigation, {:routed, ^ref, {:ok, %Route{}}}}
  end

  test "materializes the predicted next leg from the player's actual position" do
    ref = make_ref()
    navigation = %Session{ref: ref, target: {:coord, "morocc", 5, 5}, route: streaming_route()}
    state = session_state()
    game_state = %{state.game_state | map_name: "geffen", x: 2, y: 1}
    state = %{state | game_state: game_state, navigation: navigation}

    materializing = NavigationHandler.on_map_loaded(state)
    new_ref = materializing.navigation.ref
    refute new_ref == ref

    assert_receive {:navigation, {:materialized, ^new_ref, 1, {:ok, [{2, 1} | _] = cells}}}

    assert {:noreply, updated} =
             NavigationHandler.handle_materialized(materializing, new_ref, 1, {:ok, cells})

    assert %Session{leg: 1, route: route} = updated.navigation
    assert %Leg{cells: [{2, 1} | _]} = Enum.at(route.legs, 1)

    assert_received {:send, :world, {:navigate_to, %NavigateTo{legs: legs}}}
    assert %{index: 1, cells: [%{x: 2, y: 1} | _]} = Enum.at(legs, 1)
  end

  test "materializes the final leg when the destination map loads away from the arrival cell" do
    ref = make_ref()

    navigation = %Session{
      ref: ref,
      target: {:coord, "morocc", 5, 5},
      route: streaming_route(),
      leg: 1
    }

    state = session_state()
    game_state = %{state.game_state | map_name: "morocc", x: 1, y: 1}
    state = %{state | game_state: game_state, navigation: navigation}

    materializing = NavigationHandler.on_map_loaded(state)
    new_ref = materializing.navigation.ref

    assert %Session{leg: 1} = materializing.navigation
    refute new_ref == ref
    refute_received {:send, :world, {:navigation_ended, _message}}

    assert_receive {:navigation, {:materialized, ^new_ref, 2, {:ok, cells}}}
    assert hd(cells) == {1, 1}
    assert List.last(cells) == {5, 5}

    assert {:noreply, updated} =
             NavigationHandler.handle_materialized(materializing, new_ref, 2, {:ok, cells})

    assert %Session{leg: 2, route: route} = updated.navigation
    assert %Leg{cells: ^cells} = Enum.at(route.legs, 2)
  end

  test "ends navigation when the destination map loads within the arrival radius" do
    navigation = %Session{
      ref: make_ref(),
      target: {:coord, "morocc", 5, 5},
      route: streaming_route(),
      leg: 1
    }

    state = session_state()
    game_state = %{state.game_state | map_name: "morocc", x: 4, y: 4}
    state = %{state | game_state: game_state, navigation: navigation}

    updated = NavigationHandler.on_map_loaded(state)

    assert updated.navigation == nil

    assert_received {:send, :world,
                     {:navigation_ended, %NavigationEnded{reason: :NAVIGATION_END_REASON_ARRIVED}}}
  end

  test "ends a same-map navigation once a step reaches the destination" do
    navigation = %Session{ref: make_ref(), target: {:coord, "prontera", 4, 1}, route: route()}
    state = session_state()

    walking = %{
      state
      | game_state: %{state.game_state | x: 1, y: 1},
        navigation: navigation
    }

    assert ^walking = NavigationHandler.on_moved(walking)
    refute_received {:send, _channel, _message}

    arrived =
      NavigationHandler.on_moved(%{walking | game_state: %{walking.game_state | x: 3, y: 1}})

    assert arrived.navigation == nil

    assert_received {:send, :world,
                     {:navigation_ended, %NavigationEnded{reason: :NAVIGATION_END_REASON_ARRIVED}}}
  end

  test "a step on a leg that is not the final one never ends navigation" do
    navigation = %Session{
      ref: make_ref(),
      target: {:coord, "morocc", 5, 5},
      route: streaming_route()
    }

    state = session_state()
    state = %{state | navigation: navigation}

    assert ^state = NavigationHandler.on_moved(state)
    refute_received {:send, _channel, _message}
  end

  test "a step taken without an active navigation is a no-op" do
    state = session_state()

    assert ^state = NavigationHandler.on_moved(state)
    refute_received {:send, _channel, _message}
  end

  test "silently re-routes an off-route arrival to the retained target" do
    old_ref = make_ref()

    navigation = %Session{
      ref: old_ref,
      target: {:coord, "morocc", 5, 5},
      route: streaming_route(),
      flag: 37,
      hide_window: true
    }

    state = session_state()
    game_state = %{state.game_state | map_name: "morocc", x: 1, y: 1}
    state = %{state | game_state: game_state, navigation: navigation}

    updated = NavigationHandler.on_map_loaded(state)

    assert %Session{
             ref: new_ref,
             target: {:coord, "morocc", 5, 5},
             route: nil,
             flag: 37,
             hide_window: true
           } = updated.navigation

    refute new_ref == old_ref
    refute_received {:send, _channel, {:navigation_failed, _message}}
    assert_receive {:navigation, {:routed, ^new_ref, {:ok, %Route{}}}}
  end

  test "restarts an in-flight solve after a same-map teleport" do
    old_ref = make_ref()
    navigation = %Session{ref: old_ref, target: {:coord, "prontera", 5, 1}, route: nil}
    state = session_state()
    game_state = %{state.game_state | x: 3, y: 1}
    state = %{state | game_state: game_state, navigation: navigation}

    updated = NavigationHandler.on_map_loaded(state)

    assert %Session{ref: new_ref, route: nil} = updated.navigation
    refute new_ref == old_ref

    assert_receive {:navigation,
                    {:routed, ^new_ref, {:ok, %Route{legs: [%Leg{cells: [{3, 1} | _]}]}}}}
  end

  test "ignores map loads after navigation has ended" do
    state = session_state()

    assert ^state = NavigationHandler.on_map_loaded(state)
    refute_received {:send, _channel, _message}
    refute_receive {:navigation, _event}
  end

  test "re-routes when live terrain prevents materializing the next leg" do
    ref = make_ref()
    navigation = %Session{ref: ref, target: {:coord, "morocc", 5, 5}, route: streaming_route()}
    state = session_state()
    game_state = %{state.game_state | map_name: "geffen", x: 2, y: 1}
    state = %{state | game_state: game_state, navigation: navigation}

    assert {:noreply, updated} =
             NavigationHandler.handle_materialized(state, ref, 1, {:error, :no_path})

    assert %Session{ref: new_ref, route: nil} = updated.navigation
    refute new_ref == ref
    assert_receive {:navigation, {:routed, ^new_ref, _result}}
  end

  test "a newer map load invalidates an older materialization for the same leg" do
    navigation = %Session{
      ref: make_ref(),
      target: {:coord, "morocc", 5, 5},
      route: streaming_route()
    }

    state = session_state()
    first_game_state = %{state.game_state | map_name: "geffen", x: 2, y: 1}

    first =
      NavigationHandler.on_map_loaded(%{
        state
        | game_state: first_game_state,
          navigation: navigation
      })

    first_ref = first.navigation.ref

    second_game_state = %{first.game_state | x: 3}
    second = NavigationHandler.on_map_loaded(%{first | game_state: second_game_state})
    second_ref = second.navigation.ref

    refute first_ref == second_ref

    stale_cells = [{2, 1}, {3, 1}, {4, 1}]

    assert {:noreply, ^second} =
             NavigationHandler.handle_materialized(second, first_ref, 1, {:ok, stale_cells})

    refute_received {:send, _channel, {:navigate_to, _message}}
  end

  defp session_state do
    %SessionState{game_state: PlayerState.new(character()), connection_pid: self()}
  end

  defp character do
    %Character{
      id: 8_100,
      account_id: 8_200,
      name: "Navigator",
      last_map: "prontera",
      last_x: 1,
      last_y: 1,
      sex: "M",
      class: 0,
      base_level: 1,
      job_level: 1,
      hp: 40,
      sp: 10
    }
  end

  defp test_graph do
    portal = %Portal{
      id: "gef_to_moc",
      map: "geffen",
      x: 4,
      y: 1,
      to_map: "morocc",
      to_x: 1,
      to_y: 1
    }

    %{
      portals: %{portal.id => portal},
      exits_by_map: %{"geffen" => [portal]},
      landings_by_map: %{"morocc" => [portal]},
      edges: %{}
    }
  end

  defp streaming_route do
    %Route{
      legs: [
        %Leg{
          index: 0,
          map: "prontera",
          cells: [{1, 1}, {2, 1}],
          exit_portal: "prt_to_gef",
          next_map: "geffen",
          arrive: nil
        },
        %Leg{
          index: 1,
          map: "geffen",
          cells: nil,
          exit_portal: "gef_to_moc",
          next_map: "morocc",
          arrive: nil
        },
        %Leg{
          index: 2,
          map: "morocc",
          cells: nil,
          exit_portal: nil,
          next_map: nil,
          arrive: {5, 5}
        }
      ]
    }
  end

  defp route do
    %Route{
      legs: [
        %Leg{
          index: 0,
          map: "prontera",
          cells: [{1, 1}, {2, 1}, {3, 1}, {4, 1}],
          exit_portal: nil,
          next_map: nil,
          arrive: {4, 1}
        }
      ]
    }
  end
end
