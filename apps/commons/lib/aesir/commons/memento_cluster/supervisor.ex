defmodule Aesir.Commons.MementoCluster.Supervisor do
  @moduledoc """
  Supervisor for the Memento cluster management system.
  Also manages SessionManager to ensure it starts after cluster is ready.
  """
  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[MementoCluster] Starting cluster supervisor...")

    children = [
      {Aesir.Commons.MementoCluster.Manager, []},
      {Aesir.Commons.SessionManager, []}
    ]

    # rest_for_one ensures SessionManager restarts if Manager restarts
    opts = [strategy: :rest_for_one, max_restarts: 3, max_seconds: 60]
    Supervisor.init(children, opts)
  end
end
