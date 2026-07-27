defmodule Aesir.Commons.Cluster.DistributedTest do
  @moduledoc """
  Multi-node regression test for the Horde coordination layer.

  Proves that session/server entries written on one node are visible on another,
  that entries owned by a downed node disappear cluster-wide, and that the CRDT
  registry reconciles after a netsplit (the original "reconnection between
  servers sometimes doesn't work" bug).

  Excluded from the default suite via `:distributed`. These boot real peer BEAM
  nodes, so they are slow. The netsplit test deliberately partitions the cluster,
  which OTP 25+ tears down via `:global`'s `prevent_overlapping_partitions`. That
  feature must be disabled at VM boot (it cannot be toggled at runtime), so run with:

      ERL_FLAGS="-kernel prevent_overlapping_partitions false" mix test --only distributed

  Peer nodes inherit the flag from the manager's boot environment.
  """
  use ExUnit.Case

  import Aesir.TestWait

  alias Aesir.Commons.SessionManager

  @moduletag :distributed
  # Real peer BEAM nodes plus CRDT reconciliation: cluster-wide visibility is
  # seconds away, not milliseconds.
  @cluster_wait 10_000
  @moduletag timeout: 120_000

  setup_all do
    case :application.get_env(:kernel, :prevent_overlapping_partitions) do
      {:ok, false} ->
        :ok

      _ ->
        flunk("""
        These distributed tests need :global's overlapping-partition prevention
        disabled at VM boot, otherwise the deliberate netsplit tears down the
        cluster. Re-run with:

            ERL_FLAGS="-kernel prevent_overlapping_partitions false" mix test --only distributed
        """)
    end
  end

  setup do
    :ok = LocalCluster.start()

    {:ok, cluster} = LocalCluster.start_link(2, applications: [:commons])
    {:ok, [n1, n2]} = LocalCluster.nodes(cluster)

    on_exit(fn ->
      if Process.alive?(cluster), do: LocalCluster.stop(cluster)
    end)

    {:ok, cluster: cluster, n1: n1, n2: n2}
  end

  defp session_data, do: %{login_id1: 1, login_id2: 2, auth_code: 3, username: "dist"}

  test "a session written on one node is visible on another", %{n1: n1, n2: n2} do
    assert :ok = :rpc.call(n1, SessionManager, :create_session, [1_000, session_data()])

    assert {:ok, %{username: "dist"}} =
             :rpc.call(n2, SessionManager, :get_session, [1_000])
  end

  test "entries owned by a node disappear cluster-wide when it goes down", %{
    cluster: cluster,
    n1: n1,
    n2: n2
  } do
    assert :ok =
             :rpc.call(n1, SessionManager, :register_server, [
               "acc-1",
               :account_server,
               {127, 0, 0, 1},
               6_900
             ])

    assert eventually(
             fn ->
               match?(
                 [%{server_id: "acc-1"}],
                 :rpc.call(n2, SessionManager, :get_servers, [:account_server])
               )
             end,
             @cluster_wait
           )

    :ok = LocalCluster.stop(cluster, n1)

    assert eventually(
             fn ->
               :rpc.call(n2, SessionManager, :get_servers, [:account_server]) == []
             end,
             @cluster_wait
           )
  end

  test "registry reconciles after a disconnect/reconnect (netsplit heal)", %{n1: n1, n2: n2} do
    assert :ok =
             :rpc.call(n1, SessionManager, :register_server, [
               "z-1",
               :zone_server,
               {127, 0, 0, 1},
               5_121
             ])

    assert eventually(
             fn ->
               match?(
                 [%{server_id: "z-1"}],
                 :rpc.call(n2, SessionManager, :get_servers, [:zone_server])
               )
             end,
             @cluster_wait
           )

    true = :rpc.call(n2, Node, :disconnect, [n1])
    Process.sleep(500)
    true = :rpc.call(n2, Node, :connect, [n1])

    assert eventually(
             fn ->
               match?(
                 [%{server_id: "z-1"}],
                 :rpc.call(n2, SessionManager, :get_servers, [:zone_server])
               )
             end,
             @cluster_wait
           )
  end
end
