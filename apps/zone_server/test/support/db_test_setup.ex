defmodule Aesir.ZoneServer.DbTestSetup do
  @moduledoc false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Db.Layout

  @doc "Configures a process-private fixture root for the booted game mode."
  @spec configure_root(map(), String.t()) :: :ok | {:ok, keyword()}
  def configure_root(%{tmp_dir: root}, domain) do
    :ok = stub_root(root)

    dir = Path.join([root, Layout.mode_dir(GameMode.mode()), domain])
    File.mkdir_p!(dir)
    {:ok, tmp_dir: dir}
  end

  def configure_root(_context, _domain), do: :ok

  @doc "Stubs the caller's database-root lookup without modifying application configuration."
  @spec stub_root(String.t()) :: :ok
  def stub_root(root) do
    Mimic.set_mimic_private()

    Mimic.stub(Application, :get_env, fn
      :zone_server, :db_root, _default -> root
      app, key, default -> Mimic.call_original(Application, :get_env, [app, key, default])
    end)

    :ok
  end
end
