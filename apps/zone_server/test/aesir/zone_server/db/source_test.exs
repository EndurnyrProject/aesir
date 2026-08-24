defmodule Aesir.ZoneServer.Db.SourceTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Db.Source

  @moduletag :tmp_dir

  setup do
    previous = [
      {:commons, :game_mode, Application.get_env(:commons, :game_mode)},
      {:zone_server, :db_root, Application.get_env(:zone_server, :db_root)}
    ]

    on_exit(fn ->
      Enum.each(previous, fn
        {app, key, nil} -> Application.delete_env(app, key)
        {app, key, value} -> Application.put_env(app, key, value)
      end)
    end)

    :ok
  end

  test "orders glob-domain base files before import files", %{tmp_dir: root} do
    Application.put_env(:commons, :game_mode, :renewal)
    Application.put_env(:zone_server, :db_root, root)

    base_a = write_file(root, "re/items/a.yml", "[]")
    base_z = write_file(root, "re/items/z.yml", "[]")
    import_b = write_file(root, "import/items/b.yml", "[]")
    import_y = write_file(root, "import/items/y.yml", "[]")

    assert Source.sources("items") == [base_a, base_z, import_b, import_y]
    assert Source.base_dir("items") == Path.join(root, "re/items")
  end

  test "resolves a file-domain base file and its import counterpart", %{tmp_dir: root} do
    Application.put_env(:commons, :game_mode, :renewal)
    Application.put_env(:zone_server, :db_root, root)

    base = write_file(root, "re/refine/refine.yml", "{}")

    assert Source.sources("refine/refine.yml") == [base]

    import = write_file(root, "import/refine/refine.yml", "{}")

    assert Source.sources("refine/refine.yml") == [base, import]
    assert Source.base_dir("refine/refine.yml") == Path.dirname(base)
  end

  test "reports the configured database mode" do
    Application.put_env(:commons, :game_mode, :pre_renewal)

    assert Source.mode() == :pre_renewal
  end

  test "resolves an explicitly empty base file", %{tmp_dir: root} do
    Application.put_env(:commons, :game_mode, :renewal)
    Application.put_env(:zone_server, :db_root, root)

    base = write_file(root, "re/level_penalty.yml", "[]")

    assert Source.sources("level_penalty.yml") == [base]
  end

  test "resolves shared domains from the root in both modes", %{tmp_dir: root} do
    Application.put_env(:zone_server, :db_root, root)
    arrows = write_file(root, "arrows.yml", "[]")

    for mode <- [:renewal, :pre_renewal] do
      Application.put_env(:commons, :game_mode, mode)
      assert Source.sources("arrows.yml") == [arrows]
      assert Source.base_dir("arrows.yml") == root
    end
  end

  test "raises with the expected pre-renewal path and importer", %{tmp_dir: root} do
    Application.put_env(:commons, :game_mode, :pre_renewal)
    Application.put_env(:zone_server, :db_root, root)

    error = assert_raise RuntimeError, fn -> Source.sources("items") end

    assert error.message =~ "priv/db/pre-re/items"
    assert error.message =~ "mix aesir.import.items"
  end

  test "reports hand-authored domains without an importer", %{tmp_dir: root} do
    Application.put_env(:commons, :game_mode, :pre_renewal)
    Application.put_env(:zone_server, :db_root, root)

    error = assert_raise RuntimeError, fn -> Source.sources("skill_tree") end

    assert error.message =~ "priv/db/pre-re/skill_tree"
    assert error.message =~ "hand-authored"
    assert error.message =~ "no importer"
  end

  defp write_file(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
