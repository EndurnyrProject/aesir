defmodule Aesir.ZoneServer.DbTestSetupTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.DbTestSetup

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
