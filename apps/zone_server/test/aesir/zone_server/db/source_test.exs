defmodule Aesir.ZoneServer.Db.SourceTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Db.Layout
  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.DbTestSetup

  @moduletag :tmp_dir

  setup context do
    {:ok, _} = DbTestSetup.configure_root(context, "items")
    {:ok, mode_dir: Layout.mode_dir(GameMode.mode())}
  end

  test "orders glob-domain base files before import files", %{tmp_dir: root, mode_dir: mode_dir} do
    base_a = write_file(root, Path.join(mode_dir, "items/a.yml"), "[]")
    base_z = write_file(root, Path.join(mode_dir, "items/z.yml"), "[]")
    import_b = write_file(root, "import/items/b.yml", "[]")
    import_y = write_file(root, "import/items/y.yml", "[]")

    assert Source.sources("items") == [base_a, base_z, import_b, import_y]
    assert Source.base_dir("items") == Path.join([root, mode_dir, "items"])
  end

  test "resolves a file-domain base file and its import counterpart", %{
    tmp_dir: root,
    mode_dir: mode_dir
  } do
    base = write_file(root, Path.join(mode_dir, "refine/refine.yml"), "{}")

    assert Source.sources("refine/refine.yml") == [base]

    import = write_file(root, "import/refine/refine.yml", "{}")

    assert Source.sources("refine/refine.yml") == [base, import]
    assert Source.base_dir("refine/refine.yml") == Path.dirname(base)
  end

  @tag game_mode: :renewal
  test "reports the renewal database mode" do
    assert Source.mode() == :renewal
  end

  @tag game_mode: :pre_renewal
  test "reports the pre-renewal database mode" do
    assert Source.mode() == :pre_renewal
  end

  test "resolves an explicitly empty base file", %{tmp_dir: root} do
    base = write_file(root, "arrows.yml", "[]")

    assert Source.sources("arrows.yml") == [base]
  end

  test "resolves shared domains from the root in both modes", %{tmp_dir: root} do
    arrows = write_file(root, "arrows.yml", "[]")

    assert Source.sources("arrows.yml") == [arrows]
    assert Source.base_dir("arrows.yml") == root
  end

  @tag game_mode: :renewal
  test "raises with the expected renewal path and importer" do
    error = assert_raise RuntimeError, fn -> Source.sources("items") end

    assert error.message =~ "priv/db/re/items"
    assert error.message =~ "mix aesir.import.items --mode re"
  end

  @tag game_mode: :pre_renewal
  test "raises with the expected pre-renewal path and importer" do
    error = assert_raise RuntimeError, fn -> Source.sources("items") end

    assert error.message =~ "priv/db/pre-re/items"
    assert error.message =~ "mix aesir.import.items --mode pre-re"
  end

  @tag game_mode: :renewal
  test "reports the skill-tree importer when renewal data is missing" do
    error = assert_raise RuntimeError, fn -> Source.sources("skill_tree") end

    assert error.message =~ "priv/db/re/skill_tree"
    assert error.message =~ "mix aesir.import.skill_tree --mode re"
  end

  @tag game_mode: :pre_renewal
  test "reports the skill-tree importer when pre-renewal data is missing" do
    error = assert_raise RuntimeError, fn -> Source.sources("skill_tree") end

    assert error.message =~ "priv/db/pre-re/skill_tree"
    assert error.message =~ "mix aesir.import.skill_tree --mode pre-re"
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

  test "reports an explicit Renewal importer command for renewal-only domains", %{tmp_dir: root} do
    stub_source_config(:renewal, root)

    Enum.each(@level_penalty_domains, fn domain ->
      message =
        "no renewal data for db #{inspect(domain)} (expected under priv/db/re/#{domain}). " <>
          "Import it with `mix aesir.import.level_penalty --mode re` or set AESIR_DB_MODE=renewal."

      assert_raise RuntimeError, message, fn -> Source.sources(domain) end
    end)
  end

  test "reports an explicit pre-renewal importer command for a nonrestricted domain", %{
    tmp_dir: root
  } do
    stub_source_config(:pre_renewal, root)

    message =
      "no pre_renewal data for db \"items\" (expected under priv/db/pre-re/items). " <>
        "Import it with `mix aesir.import.items --mode pre-re` or set AESIR_DB_MODE=renewal."

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
