defmodule Aesir.ZoneServer.Navigation.RouterTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Navigation.Portal
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Navigation.PortalGraph.Edge
  alias Aesir.ZoneServer.Navigation.Route.Leg
  alias Aesir.ZoneServer.Navigation.Router
  alias Aesir.ZoneServer.Pathfinding

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    setup_ets_tables(%{})

    Enum.each(["start", "slow_mid", "fast_mid", "blocked_mid", "goal"], &cache_open_map/1)
    put_graph(two_chain_graph())

    on_exit(fn -> :persistent_term.erase(PortalGraph) end)

    :ok
  end

  test "chooses the cheaper portal chain and keeps the winning seed path" do
    expect(Pathfinding, :find_path, 4, fn map_data, start, goal, opts ->
      call_original(Pathfinding, :find_path, [map_data, start, goal, opts])
    end)

    assert {:ok, route} = Router.route({"start", 0, 0}, [{"goal", {2, 0}}], walk_speed: 1.0)

    assert [
             %Leg{
               index: 0,
               map: "start",
               cells: [{0, 0}, {1, 0}, {2, 0}, {3, 0}],
               exit_portal: "fast_start",
               next_map: "fast_mid",
               arrive: nil
             },
             %Leg{
               index: 1,
               map: "fast_mid",
               cells: nil,
               exit_portal: "fast_middle",
               next_map: "blocked_mid",
               arrive: nil
             },
             %Leg{
               index: 2,
               map: "blocked_mid",
               cells: nil,
               exit_portal: "fast_finish",
               next_map: "goal",
               arrive: nil
             },
             %Leg{
               index: 3,
               map: "goal",
               cells: nil,
               exit_portal: nil,
               next_map: nil,
               arrive: {2, 0}
             }
           ] = route.legs
  end

  test "starts the first cross-map leg at the route origin" do
    assert {:ok, route} = Router.route({"start", 0, 0}, [{"goal", {2, 0}}], walk_speed: 1.0)
    assert [%Leg{cells: [{0, 0} | _remaining]} | _later_legs] = route.legs
  end

  test "chooses a cheaper same-map candidate instead of the first candidate" do
    candidates = [{"goal", {2, 0}}, {"start", {1, 0}}]

    assert {:ok, route} = Router.route({"start", 0, 0}, candidates, walk_speed: 1.0)

    assert [
             %Leg{
               index: 0,
               map: "start",
               cells: [{0, 0}, {1, 0}],
               exit_portal: nil,
               next_map: nil,
               arrive: {1, 0}
             }
           ] = route.legs
  end

  test "skips portal seeds that cannot beat an available direct route" do
    detour = portal("detour", "start", {9, 9}, "slow_mid", {0, 0})
    put_graph(graph([detour], %{}))

    stub(Pathfinding, :find_path, fn map_data, start, goal, opts ->
      send(self(), {:path_requested, goal})
      call_original(Pathfinding, :find_path, [map_data, start, goal, opts])
    end)

    assert {:ok, route} = Router.route({"start", 0, 0}, [{"start", {1, 0}}], walk_speed: 1.0)
    assert [%Leg{exit_portal: nil, arrive: {1, 0}}] = route.legs
    assert_received {:path_requested, {1, 0}}
    refute_received {:path_requested, {9, 9}}
  end

  test "skips a graph map excluded at request time" do
    :ok = MapFlags.set_runtime("blocked_mid", :gvg, true)

    assert {:ok, route} = Router.route({"start", 0, 0}, [{"goal", {2, 0}}], walk_speed: 1.0)

    assert [
             %Leg{map: "start", exit_portal: "slow_start"},
             %Leg{map: "slow_mid", exit_portal: "slow_finish"},
             %Leg{map: "goal", arrive: {2, 0}}
           ] = route.legs
  end

  test "returns unreachable when no portal chain reaches a candidate" do
    cache_open_map("isolated")

    assert Router.route({"start", 0, 0}, [{"isolated", {1, 1}}], walk_speed: 1.0) ==
             {:error, :unreachable}
  end

  test "returns unreachable when the origin map has no exit portals" do
    put_graph(graph([], %{}))

    assert Router.route({"start", 0, 0}, [{"goal", {1, 1}}], walk_speed: 1.0) ==
             {:error, :unreachable}
  end

  test "all-walk route cost increases with distance" do
    candidates = [{"start", {6, 0}}, {"start", {2, 0}}]

    assert {:ok, route} = Router.route({"start", 0, 0}, candidates, walk_speed: 2.0)
    assert [%Leg{cells: [{0, 0}, {1, 0}, {2, 0}], arrive: {2, 0}}] = route.legs
  end

  test "costs the first path step omitted by the pathfinder result" do
    candidates = [{"start", {1, 1}}, {"start", {1, 0}}]

    assert {:ok, route} = Router.route({"start", 0, 0}, candidates, walk_speed: 1.0)
    assert [%Leg{cells: [{0, 0}, {1, 0}], arrive: {1, 0}}] = route.legs
  end

  test "an any-cell candidate ends at the chosen portal landing" do
    assert {:ok, route} = Router.route({"start", 0, 0}, [{"goal", :any}], walk_speed: 1.0)

    assert [
             %Leg{exit_portal: "fast_start"},
             %Leg{exit_portal: "fast_middle"},
             %Leg{exit_portal: "fast_finish"},
             %Leg{map: "goal", arrive: {0, 0}}
           ] = route.legs
  end

  defp two_chain_graph do
    portals = [
      portal("slow_start", "start", {1, 0}, "slow_mid", {0, 0}),
      portal("slow_finish", "slow_mid", {1, 0}, "goal", {0, 0}),
      portal("fast_start", "start", {3, 0}, "fast_mid", {0, 0}),
      portal("fast_middle", "fast_mid", {1, 0}, "blocked_mid", {0, 0}),
      portal("fast_finish", "blocked_mid", {1, 0}, "goal", {0, 0})
    ]

    graph(portals, %{
      "slow_start" => [edge("slow_finish", 8.0)],
      "fast_start" => [edge("fast_middle", 1.0)],
      "fast_middle" => [edge("fast_finish", 1.0)]
    })
  end

  defp graph(portals, edges) do
    %{
      portals: Map.new(portals, &{&1.id, &1}),
      exits_by_map: Enum.group_by(portals, & &1.map),
      landings_by_map: Enum.group_by(portals, & &1.to_map),
      edges: edges
    }
  end

  defp portal(id, map, {x, y}, to_map, {to_x, to_y}) do
    %Portal{id: id, map: map, x: x, y: y, to_map: to_map, to_x: to_x, to_y: to_y}
  end

  defp edge(to, cost), do: %Edge{kind: :walk, to: to, cost: cost}

  defp put_graph(graph), do: :persistent_term.put(PortalGraph, graph)

  defp cache_open_map(map_name) do
    :ets.insert(EtsTable.table_for(:map_cache), {map_name, MapData.new(map_name, 10, 10)})
  end
end
