defmodule Aesir.ZoneServer.Navigation.PortalGraphTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.Portal
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  @moduletag :tmp_dir

  setup %{tmp_dir: root} do
    setup_ets_tables(%{})

    previous_root = Application.get_env(:zone_server, :db_root)
    Application.put_env(:zone_server, :db_root, root)

    sources = [
      write_file(root, "re/warps/fixture.yml", "[]"),
      write_file(root, "navigation.yml", "[]"),
      write_file(root, "map_flags.yml", "[]"),
      write_file(root, "re/castles/fixture.yml", "[]")
    ]

    Enum.each(sources, &File.touch!(&1, 1_000_000))

    :persistent_term.put(Exclusions, MapSet.new())
    :persistent_term.erase(PortalGraph)

    on_exit(fn ->
      restore_env(:db_root, previous_root)
      :persistent_term.erase(PortalGraph)
      :persistent_term.erase(Exclusions)
      :persistent_term.put(Warps, %{by_map: %{}})
    end)

    :ok
  end

  test "a one-way warp creates no reverse portal or edge" do
    cache_map(MapData.new("nav_a", 5, 5))
    cache_map(MapData.new("nav_b", 5, 5))
    put_warps([warp("a_to_b", "nav_a", {1, 1}, "nav_b", {2, 2})])

    assert :ok = PortalGraph.reload()

    assert [%Portal{id: "a_to_b", map: "nav_a", to_map: "nav_b"}] =
             PortalGraph.exits_on("nav_a")

    assert [%Portal{id: "a_to_b"}] = PortalGraph.landings_on("nav_b")
    assert PortalGraph.exits_on("nav_b") == []
    assert PortalGraph.landings_on("nav_a") == []
    assert PortalGraph.fetch("missing") == :error
    assert PortalGraph.edges_from("missing") == []

    assert PortalGraph.edges_from("a_to_b") == []
  end

  test "warms lazily on the first lookup" do
    cache_map(MapData.new("nav_a", 5, 5))
    cache_map(MapData.new("nav_b", 5, 5))
    put_warps([warp("lazy", "nav_a", {1, 1}, "nav_b", {2, 2})])

    assert :persistent_term.get(PortalGraph, nil) == nil
    assert {:ok, %Portal{id: "lazy"}} = PortalGraph.fetch("lazy")
    assert %{portals: %{"lazy" => %Portal{}}} = :persistent_term.get(PortalGraph)
  end

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
