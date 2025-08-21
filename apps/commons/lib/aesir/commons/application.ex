defmodule Aesir.Commons.Application do
  @moduledoc false

  use Application

  alias Aesir.Commons.Banner

  @impl true
  def start(_type, _args) do
    display_banner_for_starting_apps()

    topologies = Application.get_env(:libcluster, :topologies)

    children = [
      Aesir.Repo,
      {Cluster.Supervisor, [topologies, [name: Aesir.ClusterSupervisor]]},
      {Phoenix.PubSub, name: Aesir.PubSub},
      Aesir.Commons.MementoCluster.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Commons.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp display_banner_for_starting_apps do
    cond do
      env() == :test ->
        :ok

      app_loaded?(:account_server) ->
        Banner.display(:account)

      app_loaded?(:char_server) ->
        Banner.display(:char)

      app_loaded?(:zone_server) ->
        Banner.display(:zone)

      true ->
        :ok
    end
  end

  def env do
    Application.get_env(:commons, :env)
  end

  defp app_loaded?(app) do
    loaded_apps = Application.loaded_applications() |> Enum.map(fn {name, _, _} -> name end)
    app in loaded_apps
  end
end
