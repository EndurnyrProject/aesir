defmodule Aesir.Commons.ClusterTestHelper do
  @moduledoc """
  Clears all cluster registry entries between tests by terminating every owner
  process under the local OwnerSupervisor.

  Terminating the owner is not enough on its own: Horde removes the entry from
  the CRDT asynchronously and only then repopulates the registry's local
  read-path ETS table, so the dead entries stay visible for a short window.
  A test that starts inside that window resolves a stale pid (or trips over a
  key it believes is free) and fails for reasons unrelated to its own
  behaviour. `clear_all/0` therefore waits for the deregistration to become
  locally visible, mirroring `Aesir.Commons.Cluster.Entry`'s
  registration-side wait.
  """
  alias Aesir.Commons.Cluster

  @drain_attempts 500

  @spec clear_all() :: :ok
  def clear_all do
    terminated =
      for {_, pid, _, _} <- DynamicSupervisor.which_children(Cluster.owner_supervisor()) do
        DynamicSupervisor.terminate_child(Cluster.owner_supervisor(), pid)
        pid
      end

    await_deregistered(MapSet.new(terminated), @drain_attempts)
  end

  defp await_deregistered(_pids, 0), do: :ok

  defp await_deregistered(pids, attempts) do
    registered =
      Cluster.registry()
      |> Horde.Registry.select([{{:_, :"$1", :_}, [], [:"$1"]}])
      |> MapSet.new()

    if MapSet.disjoint?(pids, registered) do
      :ok
    else
      Process.sleep(1)
      await_deregistered(pids, attempts - 1)
    end
  end
end
