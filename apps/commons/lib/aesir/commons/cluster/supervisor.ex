defmodule Aesir.Commons.Cluster.Supervisor do
  @moduledoc """
  Supervises the cluster coordination layer: the CRDT registry (single source of
  truth, auto-healing on netsplit), the local owner supervisor, and the Horde
  supervisor for item-group pools.
  """
  use Supervisor

  alias Aesir.Commons.Cluster

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Horde.Registry, name: Cluster.registry(), keys: :unique, members: :auto},
      {DynamicSupervisor, name: Cluster.owner_supervisor(), strategy: :one_for_one},
      {Horde.DynamicSupervisor,
       name: Cluster.item_group_pool_supervisor(), strategy: :one_for_one, members: :auto}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
