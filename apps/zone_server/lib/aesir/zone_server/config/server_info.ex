defmodule Aesir.ZoneServer.Config.ServerInfo do
  def cluster_id(), do: Keyword.fetch!(application_env(), :cluster_id)

  defp application_env() do
    Application.fetch_env!(:zone_server, :server_info)
  end
end
