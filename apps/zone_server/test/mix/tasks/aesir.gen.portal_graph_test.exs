defmodule Mix.Tasks.Aesir.Gen.PortalGraphTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Npc.Warps
  alias Mix.Tasks.Aesir.Gen.PortalGraph, as: Generate

  @persistent_keys [GameMode, CastleDb, Exclusions, PortalGraph, Warps]
  @moduletag :tmp_dir

  setup %{tmp_dir: root} do
    previous_root = Application.get_env(:zone_server, :db_root)
    previous_mode = Application.get_env(:commons, :game_mode)
    previous_persistent = Map.new(@persistent_keys, &{&1, :persistent_term.get(&1, :missing)})

    Application.put_env(:zone_server, :db_root, root)

    write_file(root, "navigation.yml", "[]")
    write_file(root, "map_flags.yml", "[]")

    for mode <- ["re", "pre-re"] do
      write_file(root, "#{mode}/warps/fixture.yml", "[]")
      write_file(root, "#{mode}/castles/fixture.yml", "[]")
    end

    on_exit(fn ->
      restore_env(:zone_server, :db_root, previous_root)
      restore_env(:commons, :game_mode, previous_mode)

      Enum.each(previous_persistent, fn {key, value} ->
        restore_persistent(key, value)
      end)
    end)

    :ok
  end

  test "generates renewal and pre-renewal graphs by default", %{tmp_dir: root} do
    output = capture_io(fn -> Generate.run([]) end)

    for {mode, label} <- [{"re", "renewal"}, {"pre-re", "pre-renewal"}] do
      path = cache_path(root, mode)
      assert File.exists?(path)
      assert %{graph: %{portals: %{}}} = path |> File.read!() |> :erlang.binary_to_term()
      assert output =~ "portal graph: #{label}"
      assert output =~ path
    end
  end

  test "generates only the requested mode", %{tmp_dir: root} do
    output = capture_io(fn -> Generate.run(["--mode", "pre-re"]) end)

    refute File.exists?(cache_path(root, "re"))
    assert File.exists?(cache_path(root, "pre-re"))
    assert output =~ "portal graph: pre-renewal"
    refute output =~ "portal graph: renewal"
  end

  test "forces regeneration instead of reusing the existing graph", %{tmp_dir: root} do
    capture_io(fn -> Generate.run(["--mode", "re"]) end)
    path = cache_path(root, "re")
    blob = path |> File.read!() |> :erlang.binary_to_term()
    stale = put_in(blob, [:graph, :portals], %{"stale" => :portal})
    File.write!(path, :erlang.term_to_binary(stale))

    capture_io(fn -> Generate.run(["--mode", "re"]) end)

    assert %{graph: %{portals: %{}}} = path |> File.read!() |> :erlang.binary_to_term()
  end

  test "rejects an unsupported mode" do
    assert_raise Mix.Error, ~r/expected all, re or pre-re/, fn ->
      Generate.run(["--mode", "invalid"])
    end
  end

  defp cache_path(root, mode),
    do: Path.join([root, mode, "warps", ".cache", "portal_graph.etf"])

  defp write_file(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)

  defp restore_persistent(key, :missing), do: :persistent_term.erase(key)
  defp restore_persistent(key, value), do: :persistent_term.put(key, value)
end
