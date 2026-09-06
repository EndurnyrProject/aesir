defmodule Aesir.ZoneServer.DbTestSetupTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.DbTestSetup

  setup {Mimic, :set_mimic_private}

  @tag :tmp_dir
  test "fixture roots do not change global configuration or unrelated processes",
       %{tmp_dir: root} = context do
    configured_root = Application.fetch_env(:zone_server, :db_root)
    original_root = Application.get_env(:zone_server, :db_root, nil)

    assert {:ok, _} = DbTestSetup.configure_root(context, "items")
    assert Application.fetch_env(:zone_server, :db_root) == configured_root
    assert Application.get_env(:zone_server, :db_root, nil) == root

    parent = self()

    spawn(fn ->
      send(parent, {:outside_root, Application.get_env(:zone_server, :db_root, nil)})
    end)

    assert_receive {:outside_root, ^original_root}
  end

  @tag :tmp_dir
  @tag game_mode: :renewal
  test "places renewal fixtures under re without changing the configured mode",
       %{tmp_dir: root} = context do
    configured_mode = Application.fetch_env(:commons, :game_mode)

    assert {:ok, tmp_dir: directory} = DbTestSetup.configure_root(context, "items")
    assert directory == Path.join([root, "re", "items"])
    assert File.dir?(directory)
    assert GameMode.mode() == :renewal
    assert Application.fetch_env(:commons, :game_mode) == configured_mode
  end

  @tag :tmp_dir
  @tag game_mode: :pre_renewal
  test "places classic fixtures under pre-re without changing the configured mode",
       %{tmp_dir: root} = context do
    configured_mode = Application.fetch_env(:commons, :game_mode)

    assert {:ok, tmp_dir: directory} = DbTestSetup.configure_root(context, "items")
    assert directory == Path.join([root, "pre-re", "items"])
    assert File.dir?(directory)
    assert GameMode.mode() == :pre_renewal
    assert Application.fetch_env(:commons, :game_mode) == configured_mode
  end
end
