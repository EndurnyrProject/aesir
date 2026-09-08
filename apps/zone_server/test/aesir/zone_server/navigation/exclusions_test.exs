defmodule Aesir.ZoneServer.Navigation.ExclusionsTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.TestEtsSetup
  alias Aesir.ZoneServer.Db.Layout
  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Navigation.Exclusions

  setup do
    TestEtsSetup.setup_ets_tables(%{})
    :ok = Exclusions.reload()
    :ok
  end

  test "statically excludes hostile maps but not towns" do
    assert Exclusions.statically_excluded?("aldeg_cas01")
    assert Exclusions.statically_excluded?("pvp_y_1-2")
    refute Exclusions.statically_excluded?("prontera")
  end

  test "returns only runtime gvg exclusions" do
    assert Exclusions.runtime_excluded() == MapSet.new()

    :ok = MapFlags.set_runtime("foo", :gvg, true)

    assert Exclusions.runtime_excluded() == MapSet.new(["foo"])
    refute "aldeg_cas01" in Exclusions.runtime_excluded()
  end

  @tag :tmp_dir
  test "loads static exclusions from navigation data and its import overlay", %{tmp_dir: root} do
    :ok = DbTestSetup.stub_root(root)
    on_exit(fn -> Exclusions.reload() end)

    base = write_file(root, "navigation.yml", "- hidden_base\n")
    import = write_file(root, "import/navigation.yml", "- hidden_import\n")

    map_flags =
      write_file(
        root,
        "map_flags.yml",
        """
        - map: castle_flagged
          flags: [gvg_castle]
        - map: pvp_flagged
          flags: [pvp]
        - map: noparty_flagged
          flags: [pvp_noparty]
        - map: noguild_flagged
          flags: [pvp_noguild]
        """
      )

    castles = write_file(root, mode_path("castles", "castles.yml"), "[]")

    assert Source.sources("navigation.yml") == [base, import]
    assert Exclusions.sources() == [base, import, map_flags, castles]
    :ok = Exclusions.reload()

    for map_name <- [
          "castle_flagged",
          "pvp_flagged",
          "noparty_flagged",
          "noguild_flagged",
          "hidden_base",
          "hidden_import"
        ] do
      assert Exclusions.statically_excluded?(map_name)
    end
  end

  defp mode_path(domain, file) do
    Path.join(Layout.rel_path(domain, GameMode.mode()), file)
  end

  defp write_file(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
