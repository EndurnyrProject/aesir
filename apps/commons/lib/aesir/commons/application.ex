defmodule Aesir.Commons.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)

    children = [
      Aesir.Repo,
      {Cluster.Supervisor, [topologies, [name: Aesir.ClusterSupervisor]]},
      {Phoenix.PubSub, name: Aesir.PubSub},
      Aesir.Commons.SessionManager
    ]

    opts = [strategy: :one_for_one, name: Commons.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
