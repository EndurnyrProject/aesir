defmodule Aesir.ZoneServer.Mmo.DataLoaderTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Mmo.DataLoader

  @moduletag :tmp_dir

  setup context do
    {:ok, tmp_dir: directory} = DbTestSetup.configure_root(context, "items")
    {:ok, db_dir: directory}
  end

  test "returns a fresh cached term without rebuilding", %{db_dir: directory} do
    write_file(directory, "base.yml", "[]")

    assert DataLoader.load("items", "test.etf", fn _sources -> :built end) == :built

    assert DataLoader.load("items", "test.etf", fn _sources ->
             send(self(), :rebuilt)
             :rebuilt
           end) == :built

    refute_received :rebuilt
  end

  test "invalidates the cache when a source file is edited", %{db_dir: directory} do
    source = write_file(directory, "base.yml", "[]")
    cache = Path.join(directory, ".cache/test.etf")

    assert DataLoader.load("items", "test.etf", &length/1) == 1
    File.touch!(cache, 1_000_000)
    File.touch!(source, 2_000_000)

    assert DataLoader.load("items", "test.etf", fn _sources -> :rebuilt end) == :rebuilt
  end

  test "invalidates the cache when an import source is added", %{tmp_dir: root, db_dir: directory} do
    write_file(directory, "base.yml", "[]")

    assert DataLoader.load("items", "test.etf", &length/1) == 1
    write_file(root, "import/items/custom.yml", "[]")

    assert DataLoader.load("items", "test.etf", &length/1) == 2
  end

  test "invalidates the cache when an import source is removed", %{
    tmp_dir: root,
    db_dir: directory
  } do
    write_file(directory, "base.yml", "[]")
    import = write_file(root, "import/items/custom.yml", "[]")

    assert DataLoader.load("items", "test.etf", &length/1) == 2
    File.rm!(import)

    assert DataLoader.load("items", "test.etf", &length/1) == 1
  end

  test "treats a legacy bare-term cache as stale", %{db_dir: directory} do
    source = write_file(directory, "base.yml", "[]")
    cache = Path.join(directory, ".cache/test.etf")
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

  defp write_file(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
