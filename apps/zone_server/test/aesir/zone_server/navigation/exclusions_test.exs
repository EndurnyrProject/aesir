defmodule Aesir.ZoneServer.Navigation.ExclusionsTest do
  use ExUnit.Case, async: false

  alias Aesir.TestEtsSetup
  alias Aesir.ZoneServer.Db.Source
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
    previous_root = Application.get_env(:zone_server, :db_root)

    on_exit(fn ->
      restore_db_root(previous_root)
      :ok = Exclusions.reload()
    end)

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

    castles = write_file(root, "re/castles/castles.yml", "[]")

    Application.put_env(:zone_server, :db_root, root)

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

  defp write_file(root, relative_path, contents) do
    path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end

  defp restore_db_root(nil), do: Application.delete_env(:zone_server, :db_root)
  defp restore_db_root(root), do: Application.put_env(:zone_server, :db_root, root)
end
