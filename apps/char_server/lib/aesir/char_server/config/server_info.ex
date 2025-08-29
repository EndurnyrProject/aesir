defmodule Aesir.CharServer.Config.ServerInfo do
  def name(), do: Keyword.fetch!(application_env(), :name)

  def cluster_id(), do: Keyword.fetch!(application_env(), :cluster_id)

  defp application_env() do
    Application.fetch_env!(:char_server, :server_info)
  end
end
