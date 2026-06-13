defmodule Aesir.Commons.ClusterTestHelper do
  @moduledoc """
  Clears all cluster registry entries between tests by terminating every owner
  process under the local OwnerSupervisor.
  """
  alias Aesir.Commons.Cluster

  @spec clear_all() :: :ok
  def clear_all do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Cluster.owner_supervisor()) do
      DynamicSupervisor.terminate_child(Cluster.owner_supervisor(), pid)
    end

    :ok
  end
end
