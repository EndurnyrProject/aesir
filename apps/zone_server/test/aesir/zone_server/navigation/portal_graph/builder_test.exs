defmodule Aesir.ZoneServer.Navigation.PortalGraph.BuilderTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.Flood
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Navigation.PortalGraph.Builder
  alias Aesir.ZoneServer.Navigation.PortalGraph.Edge
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  @moduletag :tmp_dir

  setup %{tmp_dir: root} do
    setup_ets_tables(%{})

    previous_root = Application.get_env(:zone_server, :db_root)
    Application.put_env(:zone_server, :db_root, root)

    warp_source = write_file(root, "re/warps/fixture.yml", "[]")
    exclusion_source = write_file(root, "navigation.yml", "[]")
    map_flags_source = write_file(root, "map_flags.yml", "[]")
    castle_source = write_file(root, "re/castles/fixture.yml", "[]")
    map_source = write_file(root, "maps.mcache", "fixture")

    for source <- [warp_source, exclusion_source, map_flags_source, castle_source, map_source] do
      File.touch!(source, 1_000_000)
    end

    :persistent_term.put(Exclusions, MapSet.new())
    :persistent_term.erase(PortalGraph)

    on_exit(fn ->
      restore_env(:db_root, previous_root)
      :persistent_term.erase(PortalGraph)
      :persistent_term.erase(Exclusions)
      :persistent_term.put(Warps, %{by_map: %{}})
    end)

    {:ok, warp_source: warp_source, exclusion_source: exclusion_source, map_source: map_source}
  end

  test "walk edges carry the weighted flood cost", %{map_source: map_source} do
    cache_map(MapData.new("nav_start", 6, 6))
    middle = cache_map(MapData.new("nav_middle", 6, 6))
    cache_map(MapData.new("nav_end", 6, 6))

    put_warps([
      warp("enter_middle", "nav_start", {1, 1}, "nav_middle", {0, 0}),
      warp("leave_middle", "nav_middle", {4, 2}, "nav_end", {1, 1})
    ])

    graph = Builder.load(map_cache_path: map_source)
    :persistent_term.put(PortalGraph, graph)

    expected =
      Flood.costs(middle, {0, 0}, MapSet.new([{4, 2}]), terrain: :static)[{4, 2}]

    assert [%Edge{kind: :walk, to: "leave_middle", cost: cost}] =
             PortalGraph.edges_from("enter_middle")

    assert_in_delta cost, expected, 1.0e-12
    assert graph.edges["leave_middle"] == []
  end

  test "a blocked landing is nudged to its nearest walkable cell", %{map_source: map_source} do
    cache_map(MapData.new("nav_start", 6, 6))

    middle =
      "nav_middle"
      |> MapData.new(6, 6)
      |> MapData.set_cell(2, 2, GatType.wall())
      |> cache_map()

    cache_map(MapData.new("nav_end", 6, 6))

    put_warps([
      warp("blocked_landing", "nav_start", {1, 1}, "nav_middle", {2, 2}),
      warp("middle_exit", "nav_middle", {5, 2}, "nav_end", {1, 1})
    ])

    graph = Builder.load(map_cache_path: map_source)
    [%Edge{kind: :walk, cost: cost}] = graph.edges["blocked_landing"]

    expected =
      Flood.costs(middle, {1, 1}, MapSet.new([{5, 2}]), terrain: :static)[{5, 2}]

    assert_in_delta cost, expected, 1.0e-12
  end

  test "runtime terrain does not change the built graph", %{
    map_source: map_source,
    warp_source: warp_source
  } do
    cache_map(MapData.new("nav_start", 5, 3))

    middle =
      for x <- 0..4, y <- [0, 2], reduce: MapData.new("nav_middle", 5, 3) do
        map_data -> MapData.set_cell(map_data, x, y, GatType.wall())
      end
      |> cache_map()

    cache_map(MapData.new("nav_end", 5, 3))

    put_warps([
      warp("enter_middle", "nav_start", {1, 1}, "nav_middle", {0, 1}),
      warp("leave_middle", "nav_middle", {4, 1}, "nav_end", {1, 1})
    ])

    without_blocker = Builder.load(map_cache_path: map_source)

    :ok = Cell.put("nav_middle", 2, 1, :ice_wall, 1, blocks_movement: true)
    File.write!(warp_source, "[changed]\n")

    with_blocker = Builder.load(map_cache_path: map_source)

    assert with_blocker.edges == without_blocker.edges
    assert [%Edge{kind: :walk, cost: 4.0}] = with_blocker.edges["enter_middle"]
    refute Map.has_key?(Flood.costs(middle, {0, 1}, MapSet.new([{4, 1}])), {4, 1})
  end

  test "portals touching a statically excluded map are absent", %{map_source: map_source} do
    for map_name <- ["nav_allowed", "nav_hidden", "nav_other"] do
      cache_map(MapData.new(map_name, 4, 4))
    end

    :persistent_term.put(Exclusions, MapSet.new(["nav_hidden"]))

    put_warps([
      warp("into_hidden", "nav_allowed", {1, 1}, "nav_hidden", {1, 1}),
      warp("out_of_hidden", "nav_hidden", {2, 2}, "nav_other", {1, 1})
    ])

    graph = Builder.load(map_cache_path: map_source)
    :persistent_term.put(PortalGraph, graph)

    assert PortalGraph.exits_on("nav_hidden") == []
    assert PortalGraph.landings_on("nav_hidden") == []
    assert PortalGraph.exits_on("nav_allowed") == []
    assert PortalGraph.landings_on("nav_other") == []
    assert PortalGraph.fetch("into_hidden") == :error
    assert PortalGraph.fetch("out_of_hidden") == :error
  end

  test "unchanged inputs reuse the ETF graph", %{map_source: map_source} do
    seed_cache_fixture()
    put_warps([warp("first", "nav_a", {1, 1}, "nav_b", {1, 1})])

    first = Builder.load(map_cache_path: map_source)

    put_warps([
      warp("first", "nav_a", {1, 1}, "nav_b", {1, 1}),
      warp("second", "nav_b", {2, 2}, "nav_a", {2, 2})
    ])

    second = Builder.load(map_cache_path: map_source)

    assert first == second
    refute Map.has_key?(second.portals, "second")
  end

  test "changing a warp source within the same POSIX second invalidates the cache", %{
    map_source: map_source,
    warp_source: warp_source
  } do
    seed_cache_fixture()
    put_warps([warp("first", "nav_a", {1, 1}, "nav_b", {1, 1})])
    _graph = Builder.load(map_cache_path: map_source)

    put_warps([
      warp("first", "nav_a", {1, 1}, "nav_b", {1, 1}),
      warp("second", "nav_b", {2, 2}, "nav_a", {2, 2})
    ])

    mtime = File.stat!(warp_source, time: :posix).mtime
    File.write!(warp_source, "[changed]\n")
    File.touch!(warp_source, mtime)

    assert File.stat!(warp_source, time: :posix).mtime == mtime

    rebuilt = Builder.load(map_cache_path: map_source)

    assert Map.has_key?(rebuilt.portals, "second")
  end

  test "changing maps.mcache contents invalidates the cache", %{map_source: map_source} do
    seed_cache_fixture()
    put_warps([warp("first", "nav_a", {1, 1}, "nav_b", {1, 1})])
    _graph = Builder.load(map_cache_path: map_source)

    put_warps([
      warp("first", "nav_a", {1, 1}, "nav_b", {1, 1}),
      warp("second", "nav_b", {2, 2}, "nav_a", {2, 2})
    ])

    File.write!(map_source, "changed")

    rebuilt = Builder.load(map_cache_path: map_source)

    assert Map.has_key?(rebuilt.portals, "second")
  end

  test "changing a static exclusion source invalidates the cache", %{
    exclusion_source: exclusion_source,
    map_source: map_source
  } do
    seed_cache_fixture()
    put_warps([warp("first", "nav_a", {1, 1}, "nav_b", {1, 1})])
    _graph = Builder.load(map_cache_path: map_source)

    put_warps([
      warp("first", "nav_a", {1, 1}, "nav_b", {1, 1}),
      warp("second", "nav_b", {2, 2}, "nav_a", {2, 2})
    ])

    File.write!(exclusion_source, "[changed]\n")

    rebuilt = Builder.load(map_cache_path: map_source)

    assert Map.has_key?(rebuilt.portals, "second")
  end

  test "a corrupt ETF cache is rebuilt", %{map_source: map_source, tmp_dir: root} do
    seed_cache_fixture()
    put_warps([warp("first", "nav_a", {1, 1}, "nav_b", {1, 1})])
    _graph = Builder.load(map_cache_path: map_source)

    put_warps([
      warp("first", "nav_a", {1, 1}, "nav_b", {1, 1}),
      warp("second", "nav_b", {2, 2}, "nav_a", {2, 2})
    ])

    File.write!(cache_path(root), "not an external term")

    rebuilt = Builder.load(map_cache_path: map_source)

    assert Map.has_key?(rebuilt.portals, "second")
    assert %{graph: ^rebuilt} = cache_path(root) |> File.read!() |> :erlang.binary_to_term()
  end

  defp seed_cache_fixture do
    cache_map(MapData.new("nav_a", 4, 4))
    cache_map(MapData.new("nav_b", 4, 4))
  end

  defp cache_path(root), do: Path.join(root, "re/warps/.cache/portal_graph.etf")

  defp warp(id, map, {x, y}, to_map, {to_x, to_y}) do
    %Warp{
      id: id,
      map: map,
      x: x,
      y: y,
      to_map: to_map,
      to_x: to_x,
      to_y: to_y
    }
  end

  defp put_warps(warps) do
    :persistent_term.put(Warps, %{by_map: Enum.group_by(warps, & &1.map)})
  end

  defp cache_map(map_data) do
    :ets.insert(EtsTable.table_for(:map_cache), {map_data.name, map_data})
    map_data
  end

  defp write_file(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end

  defp restore_env(key, nil), do: Application.delete_env(:zone_server, key)
  defp restore_env(key, value), do: Application.put_env(:zone_server, key, value)
end
