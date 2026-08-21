defmodule Aesir.ZoneServer.Mmo.DataLoaderTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.DataLoader

  @moduletag :tmp_dir

  setup do
    previous =
      for key <- [:db_mode, :db_root] do
        {key, Application.get_env(:zone_server, key)}
      end

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> Application.delete_env(:zone_server, key)
        {key, value} -> Application.put_env(:zone_server, key, value)
      end)
    end)

    :ok
  end

  test "returns a fresh cached term without rebuilding", %{tmp_dir: root} do
    configure_root(root)
    write_file(root, "re/items/base.yml", "[]")

    assert DataLoader.load("items", "test.etf", fn _sources -> :built end) == :built

    assert DataLoader.load("items", "test.etf", fn _sources ->
             send(self(), :rebuilt)
             :rebuilt
           end) == :built

    refute_received :rebuilt
  end

  test "invalidates the cache when a source file is edited", %{tmp_dir: root} do
    configure_root(root)
    source = write_file(root, "re/items/base.yml", "[]")
    cache = Path.join([root, "re/items/.cache/test.etf"])

    assert DataLoader.load("items", "test.etf", &length/1) == 1
    File.touch!(cache, 1_000_000)
    File.touch!(source, 2_000_000)

    assert DataLoader.load("items", "test.etf", fn _sources -> :rebuilt end) == :rebuilt
  end

  test "invalidates the cache when an import source is added", %{tmp_dir: root} do
    configure_root(root)
    write_file(root, "re/items/base.yml", "[]")

    assert DataLoader.load("items", "test.etf", &length/1) == 1
    write_file(root, "import/items/custom.yml", "[]")

    assert DataLoader.load("items", "test.etf", &length/1) == 2
  end

  test "invalidates the cache when an import source is removed", %{tmp_dir: root} do
    configure_root(root)
    write_file(root, "re/items/base.yml", "[]")
    import = write_file(root, "import/items/custom.yml", "[]")

    assert DataLoader.load("items", "test.etf", &length/1) == 2
    File.rm!(import)

    assert DataLoader.load("items", "test.etf", &length/1) == 1
  end

  test "treats a legacy bare-term cache as stale", %{tmp_dir: root} do
    configure_root(root)
    source = write_file(root, "re/items/base.yml", "[]")
    cache = Path.join([root, "re/items/.cache/test.etf"])
    File.mkdir_p!(Path.dirname(cache))
    File.write!(cache, :erlang.term_to_binary(:legacy))
    File.touch!(source, 1_000_000)
    File.touch!(cache, 2_000_000)

    assert DataLoader.load("items", "test.etf", fn _sources -> :rebuilt end) == :rebuilt

    assert %{sources: [^source], term: :rebuilt} =
             cache |> File.read!() |> :erlang.binary_to_term()
  end

  test "merge_by_key keeps first occurrence order while the last entry wins" do
    entries = [
      %{id: 1, value: :base_one},
      %{id: 2, value: :base_two},
      %{id: 1, value: :custom_one},
      %{id: 3, value: :custom_three}
    ]

    assert DataLoader.merge_by_key(entries, & &1.id) == [
             %{id: 1, value: :custom_one},
             %{id: 2, value: :base_two},
             %{id: 3, value: :custom_three}
           ]
  end

  defp configure_root(root) do
    Application.put_env(:zone_server, :db_mode, :renewal)
    Application.put_env(:zone_server, :db_root, root)
  end

  defp write_file(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
