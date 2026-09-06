defmodule Aesir.ZoneServer.DbTestSetup do
  @moduledoc false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Db.Layout

  @doc "Configures a temporary mode-scoped database directory without changing the boot mode."
  @spec configure_root(map(), String.t()) :: :ok | {:ok, keyword()}
  def configure_root(%{tmp_dir: root}, domain) do
    previous = Application.fetch_env(:zone_server, :db_root)
    Application.put_env(:zone_server, :db_root, root)

    ExUnit.Callbacks.on_exit(fn ->
      case previous do
        :error -> Application.delete_env(:zone_server, :db_root)
        {:ok, value} -> Application.put_env(:zone_server, :db_root, value)
      end
    end)

    dir = Path.join([root, Layout.mode_dir(GameMode.mode()), domain])
    File.mkdir_p!(dir)
    {:ok, tmp_dir: dir}
  end

  def configure_root(_context, _domain), do: :ok
end
