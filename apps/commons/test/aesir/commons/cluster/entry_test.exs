defmodule Aesir.Commons.Cluster.EntryTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.Cluster.Entry

  setup do
    on_exit(fn ->
      for {_, pid, _, _} <- DynamicSupervisor.which_children(Cluster.owner_supervisor()) do
        DynamicSupervisor.terminate_child(Cluster.owner_supervisor(), pid)
      end
    end)

    :ok
  end

  defp start_entry(opts) do
    DynamicSupervisor.start_child(Cluster.owner_supervisor(), {Entry, opts})
  end

  test "registers a value that is readable via the registry" do
    {:ok, _pid} = start_entry(key: {:t, 1}, value: %{a: 1})
    assert [{_pid, %{a: 1}}] = Horde.Registry.lookup(Cluster.registry(), {:t, 1})
  end

  test "update/2 mutates the registered value" do
    {:ok, pid} = start_entry(key: {:t, 2}, value: %{n: 0})
    assert {:ok, %{n: 5}} = Entry.update(pid, fn v -> %{v | n: 5} end)
    assert [{_, %{n: 5}}] = Horde.Registry.lookup(Cluster.registry(), {:t, 2})
  end

  test "stops (and unregisters) when its anchor dies" do
    anchor = spawn(fn -> Process.sleep(:infinity) end)
    {:ok, pid} = start_entry(key: {:t, 3}, value: %{}, anchor: anchor)
    ref = Process.monitor(pid)
    Process.exit(anchor, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000
    assert [] = Horde.Registry.lookup(Cluster.registry(), {:t, 3})
  end

  test "self-terminates after its ttl elapses" do
    {:ok, pid} = start_entry(key: {:t, 4}, value: %{}, ttl: 50)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
    assert [] = Horde.Registry.lookup(Cluster.registry(), {:t, 4})
  end
end
