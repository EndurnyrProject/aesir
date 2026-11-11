defmodule Aesir.CharServer.Config.ServerInfo do
  def name(), do: Keyword.fetch!(application_env(), :name)

  @doc "Display region shown on the client's server select screen; empty when unset."
  def region(), do: Keyword.fetch!(application_env(), :region)

  @doc "One-line description shown on the client's server select screen; empty when unset."
  def description(), do: Keyword.fetch!(application_env(), :description)

  def cluster_id(), do: Keyword.fetch!(application_env(), :cluster_id)

  defp application_env() do
    Application.fetch_env!(:char_server, :server_info)
  end
end
