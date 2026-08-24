defmodule Aesir.ZoneServer.DbTestSetup do
  @moduledoc false

  @spec configure_root(map(), String.t()) :: :ok | {:ok, keyword()}
  def configure_root(%{tmp_dir: root}, domain) do
    previous = [
      {:commons, :game_mode, Application.get_env(:commons, :game_mode)},
      {:zone_server, :db_root, Application.get_env(:zone_server, :db_root)}
    ]

    Application.put_env(:commons, :game_mode, :renewal)
    Application.put_env(:zone_server, :db_root, root)

    ExUnit.Callbacks.on_exit(fn ->
      Enum.each(previous, fn
        {app, key, nil} -> Application.delete_env(app, key)
        {app, key, value} -> Application.put_env(app, key, value)
      end)
    end)

    dir = Path.join([root, "re", domain])
    File.mkdir_p!(dir)
    {:ok, tmp_dir: dir}
  end

  def configure_root(_context, _domain), do: :ok
end
