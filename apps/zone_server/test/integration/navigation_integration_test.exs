defmodule Aesir.ZoneServer.Integration.NavigationIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.MapLoaded
  alias Aesir.Net.NavigateTo
  alias Aesir.Net.NavigationCancel
  alias Aesir.Net.NavigationCell
  alias Aesir.Net.NavigationCoordinate
  alias Aesir.Net.NavigationEnded
  alias Aesir.Net.NavigationFailed
  alias Aesir.Net.NavigationRequest

  alias Aesir.ZoneServer.Content.Npc.Re.Jobs.Novice.Academy.IzInt5130,
    as: CommittedNavigationNpc

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns
  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Navigation.SpawnIndex
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Script.Ctx

  @origin {150, 150}
  @destination {203, 146}
  @graph_budget_ms 120_000
  @persistent_keys [Warps, PortalGraph, SpawnIndex, Exclusions]

  setup_all do
    previous_persistent =
      Map.new(@persistent_keys, &{&1, :persistent_term.get(&1, :missing)})

    :ok = Warps.reload()

    started_at = System.monotonic_time(:millisecond)
    :ok = PortalGraph.reload()
    graph_load_ms = System.monotonic_time(:millisecond) - started_at
    :ok = SpawnIndex.reload()

    on_exit(fn ->
      Enum.each(previous_persistent, fn {key, value} ->
        restore_persistent(key, value)
      end)
    end)

    {:ok, graph_load_ms: graph_load_ms}
  end

  test "routes from Prontera to a real Geffen coordinate over real portal data", context do
    assert context.graph_load_ms < @graph_budget_ms

    player = start_player_session(id: 10_001, name: "Navigator", position: @origin)
    flush_packets()

    {destination_x, destination_y} = @destination

    simulate_incoming_message(player.pid, %NavigationRequest{
      target: {:coord, %NavigationCoordinate{map: "geffen", x: destination_x, y: destination_y}},
      flag: 73,
      hide_window: true
    })

    packet = await_packet(NavigateTo)

    assert %NavigateTo{
             map: "geffen",
             x: ^destination_x,
             y: ^destination_y,
             flag: 73,
             hide_window: true,
             destination: %NavigationCoordinate{
               map: "geffen",
               x: ^destination_x,
               y: ^destination_y
             }
           } = packet

    assert length(packet.legs) > 1
    assert Enum.map(packet.legs, & &1.index) == Enum.to_list(0..(length(packet.legs) - 1))

    session = PlayerSession.get_state(player.pid).navigation
    first_leg = hd(session.route.legs)
    first_wire_leg = hd(packet.legs)
    origin_cell = navigation_cell(@origin)

    assert first_leg.map == "prontera"
    assert hd(first_leg.cells) == @origin
    assert first_wire_leg.cells |> hd() == origin_cell
    assert Enum.all?(first_leg.cells, fn {x, y} -> Cell.traversable?("prontera", x, y) end)
    assert valid_walk_path?("prontera", first_leg.cells)

    {:ok, first_portal} = PortalGraph.fetch(first_leg.exit_portal)
    assert List.last(first_leg.cells) == {first_portal.x, first_portal.y}
    assert first_leg.next_map == first_portal.to_map

    assert Enum.all?(Enum.chunk_every(packet.legs, 2, 1, :discard), fn [leg, next_leg] ->
             leg.next_map == next_leg.map
           end)

    assert List.last(packet.legs).map == "geffen"
    assert List.last(session.route.legs).arrive == @destination
  end

  test "streams detailed legs on each predicted map and ends on the final map" do
    player = start_player_session(id: 10_002, name: "Walker", position: @origin)
    flush_packets()

    simulate_incoming_message(player.pid, %NavigationRequest{target: {:map, "geffen"}})
    initial = await_packet(NavigateTo)

    assert length(initial.legs) > 1
    follow_route(player)
    assert PlayerSession.get_state(player.pid).navigation == nil
  end

  test "re-routes from an unexpected teleport and can then be cancelled" do
    player = start_player_session(id: 10_003, name: "Wayward", position: @origin)
    flush_packets()

    {destination_x, destination_y} = @destination

    simulate_incoming_message(player.pid, %NavigationRequest{
      target: {:coord, %NavigationCoordinate{map: "geffen", x: destination_x, y: destination_y}}
    })

    _initial = await_packet(NavigateTo)
    old_ref = PlayerSession.get_state(player.pid).navigation.ref

    PlayerSession.warp(player.pid, "payon", 100, 100)

    assert_eventually(fn ->
      PlayerSession.get_state(player.pid).game_state.map_name == "payon"
    end)

    simulate_incoming_message(player.pid, %MapLoaded{})
    corrected = await_packet(NavigateTo)
    state = PlayerSession.get_state(player.pid)
    actual = {state.game_state.x, state.game_state.y}

    assert state.navigation.ref != old_ref
    assert state.navigation.target == {:coord, "geffen", destination_x, destination_y}
    assert hd(state.navigation.route.legs).map == "payon"
    assert hd(hd(state.navigation.route.legs).cells) == actual
    assert hd(corrected.legs).map == "payon"
    assert hd(hd(corrected.legs).cells) == navigation_cell(actual)

    simulate_incoming_message(player.pid, %NavigationCancel{})

    assert %NavigationEnded{reason: :NAVIGATION_END_REASON_CANCELLED} =
             await_packet(NavigationEnded)

    assert PlayerSession.get_state(player.pid).navigation == nil
  end

  test "resolves monster, NPC, map-only, already-there, and unknown targets distinctly" do
    player = start_player_session(id: 10_004, name: "Searcher", position: @origin)
    flush_packets()

    simulate_incoming_message(player.pid, %NavigationRequest{target: {:monster, 1_002}})
    monster_route = await_packet(NavigateTo, 15_000)

    assert monster_route.monster_id == 1_002
    assert monster_route.map in SpawnIndex.maps_for_mob(1_002)
    assert {:ok, spawns} = Spawns.for_map(monster_route.map)
    assert Enum.any?(spawns, &(&1.mob == 1_002))

    simulate_incoming_message(player.pid, %NavigationRequest{target: {:npc, "Citizen"}})
    npc_route = await_packet(NavigateTo, 15_000)

    npc_destinations =
      NpcRegistry.by_name("Citizen")
      |> Enum.map(fn {_module, placement} -> {placement.map, placement.x, placement.y} end)

    assert {npc_route.map, npc_route.x, npc_route.y} in npc_destinations
    assert npc_route.monster_id == 0

    simulate_incoming_message(player.pid, %NavigationRequest{target: {:map, "geffen"}})
    map_route = await_packet(NavigateTo, 15_000)
    assert map_route.map == "geffen"

    simulate_incoming_message(player.pid, %NavigationRequest{target: {:map, "prontera"}})

    assert %NavigationFailed{reason: :NAVIGATION_FAILURE_REASON_ALREADY_THERE} =
             await_packet(NavigationFailed)

    simulate_incoming_message(player.pid, %NavigationRequest{target: {:npc, "missing-npc"}})

    assert %NavigationFailed{reason: :NAVIGATION_FAILURE_REASON_UNRESOLVED} =
             await_packet(NavigationFailed)
  end

  test "rejects a destination excluded at request time" do
    player = start_player_session(id: 10_005, name: "Excluded", position: @origin)
    flush_packets()

    :ok = MapFlags.set_runtime("geffen", :gvg, true)
    on_exit(fn -> MapFlags.clear_runtime("geffen", :gvg) end)

    simulate_incoming_message(player.pid, %NavigationRequest{target: {:map, "geffen"}})

    assert %NavigationFailed{reason: :NAVIGATION_FAILURE_REASON_UNREACHABLE} =
             await_packet(NavigationFailed)

    refute_packet_sent(NavigateTo)
    assert PlayerSession.get_state(player.pid).navigation == nil
  end

  test "a committed transpiled navigateto call site starts a real route" do
    player =
      start_player_session(
        id: 10_006,
        name: "Transpiled",
        map_name: "int_land",
        position: {75, 100}
      )

    flush_packets()
    state = PlayerSession.get_state(player.pid)

    ctx =
      %{game_state: state.game_state, connection_pid: player.connection_pid}
      |> Ctx.from_session({:npc, CommittedNavigationNpc.npc_id()})
      |> Map.put(:session_pid, player.pid)

    assert CommittedNavigationNpc.ev_ontouch(ctx) == ctx

    assert %NavigateTo{
             map: "int_land",
             x: 75,
             y: 100,
             hide_window: true
           } = await_packet(NavigateTo, 15_000)
  end

  test "logging out discards an active navigation session" do
    player = start_player_session(id: 10_007, name: "Logout", position: @origin)
    flush_packets()

    simulate_incoming_message(player.pid, %NavigationRequest{target: {:map, "geffen"}})
    _route = await_packet(NavigateTo)
    assert PlayerSession.get_state(player.pid).navigation != nil

    monitor = Process.monitor(player.pid)
    assert :ok = end_player_session(player)
    assert_receive {:DOWN, ^monitor, :process, _pid, :normal}
    refute Process.alive?(player.pid)
  end

  defp follow_route(player) do
    state = PlayerSession.get_state(player.pid)
    navigation = state.navigation
    current_leg = Enum.at(navigation.route.legs, navigation.leg)
    assert valid_walk_path?(current_leg.map, current_leg.cells)
    next_index = navigation.leg + 1
    final_index = length(navigation.route.legs) - 1

    {:ok, portal} = PortalGraph.fetch(current_leg.exit_portal)
    # The detailed path is validated cell-by-cell; cross the portal directly so
    # the test exercises the real WarpHandler/MapLoad flow without waiting for
    # real-time movement ticks across every map.
    PlayerSession.warp(player.pid, portal.to_map, portal.to_x, portal.to_y)

    assert_eventually(fn ->
      PlayerSession.get_state(player.pid).game_state.map_name == portal.to_map
    end)

    simulate_incoming_message(player.pid, %MapLoaded{})

    if next_index == final_index do
      assert %NavigationEnded{reason: :NAVIGATION_END_REASON_ARRIVED} =
               await_packet(NavigationEnded)
    else
      packet = await_packet(NavigateTo)
      state = PlayerSession.get_state(player.pid)
      assert state.navigation.leg == next_index

      actual = {state.game_state.x, state.game_state.y}
      detailed_leg = Enum.at(state.navigation.route.legs, next_index)
      wire_leg = Enum.at(packet.legs, next_index)

      assert hd(detailed_leg.cells) == actual
      assert valid_walk_path?(state.game_state.map_name, detailed_leg.cells)
      assert hd(wire_leg.cells) == navigation_cell(actual)
      follow_route(player)
    end
  end

  defp await_packet(packet_type, timeout \\ 15_000) do
    receive do
      {:packet_sent, %{__struct__: ^packet_type} = packet, _channel} -> packet
    after
      timeout -> flunk("expected #{inspect(packet_type)} within #{timeout}ms")
    end
  end

  defp valid_walk_path?(map_name, cells) do
    cells
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [{x1, y1} = from, {x2, y2} = to] ->
      max(abs(x2 - x1), abs(y2 - y1)) == 1 and
        Cell.step_traversable?(map_name, from, to)
    end)
  end

  defp restore_persistent(key, :missing), do: :persistent_term.erase(key)
  defp restore_persistent(key, value), do: :persistent_term.put(key, value)

  defp navigation_cell({x, y}), do: %NavigationCell{x: x, y: y}
end
