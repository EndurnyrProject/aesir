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

defmodule Aesir.ZoneServer.Db.SourceModeRestrictionTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Db.Source

  @level_penalty_domains ~w(
    level_penalty.yml
    level_penalty_exp.yml
    level_penalty_mvp_drop.yml
    level_penalty_mvp_exp.yml
  )

  @moduletag :tmp_dir

  setup :set_mimic_private
  setup :verify_on_exit!

  test "returns no sources for renewal-only domains in pre-renewal", %{tmp_dir: root} do
    stub_source_config(:pre_renewal, root)

    Enum.each(@level_penalty_domains, fn domain ->
      write_file(root, Path.join("pre-re", domain), "16: 50\n")
      write_file(root, Path.join("import", domain), "16: 40\n")

      assert Source.sources(domain) == []
    end)
  end

  test "resolves renewal sources for every renewal-only domain", %{tmp_dir: root} do
    stub_source_config(:renewal, root)

    Enum.each(@level_penalty_domains, fn domain ->
      base = write_file(root, Path.join("re", domain), "16: 50\n")
      import = write_file(root, Path.join("import", domain), "16: 40\n")

      assert Source.sources(domain) == [base, import]
    end)
  end

  test "preserves the renewal missing-data error for renewal-only domains", %{tmp_dir: root} do
    stub_source_config(:renewal, root)

    Enum.each(@level_penalty_domains, fn domain ->
      message =
        "no renewal data for db #{inspect(domain)} (expected under priv/db/re/#{domain}). " <>
          "Import it with `mix aesir.import.level_penalty` or set AESIR_DB_MODE=renewal."

      assert_raise RuntimeError, message, fn -> Source.sources(domain) end
    end)
  end

  test "preserves the missing-data error for a nonrestricted pre-renewal domain", %{
    tmp_dir: root
  } do
    stub_source_config(:pre_renewal, root)

    message =
      "no pre_renewal data for db \"items\" (expected under priv/db/pre-re/items). " <>
        "Import it with `mix aesir.import.items` or set AESIR_DB_MODE=renewal."

    assert_raise RuntimeError, message, fn -> Source.sources("items") end
  end

  test "validates a domain before applying mode restrictions" do
    assert_raise ArgumentError, "unknown database domain: \"unknown.yml\"", fn ->
      Source.sources("unknown.yml")
    end
  end

  defp stub_source_config(mode, root) do
    stub(GameMode, :mode, fn -> mode end)
    stub(Application, :get_env, fn :zone_server, :db_root, _default -> root end)
  end

  defp write_file(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
