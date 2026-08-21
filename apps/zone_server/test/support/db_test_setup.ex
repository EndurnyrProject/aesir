defmodule Aesir.ZoneServer.DbTestSetup do
  @moduledoc false

  @spec configure_root(map(), String.t()) :: :ok | {:ok, keyword()}
  def configure_root(%{tmp_dir: root}, domain) do
    previous =
      for key <- [:db_mode, :db_root] do
        {key, Application.get_env(:zone_server, key)}
      end

    Application.put_env(:zone_server, :db_mode, :renewal)
    Application.put_env(:zone_server, :db_root, root)

    ExUnit.Callbacks.on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> Application.delete_env(:zone_server, key)
        {key, value} -> Application.put_env(:zone_server, key, value)
      end)
    end)

    dir = Path.join([root, "re", domain])
    File.mkdir_p!(dir)
    {:ok, tmp_dir: dir}
  end

  def configure_root(_context, _domain), do: :ok
end
