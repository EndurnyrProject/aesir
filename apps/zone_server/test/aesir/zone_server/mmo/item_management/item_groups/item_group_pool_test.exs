defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPoolTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.Cluster
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup

  setup do
    previous_catalog = :persistent_term.get(ItemGroups, :missing)

    on_exit(fn ->
      case previous_catalog do
        :missing -> :persistent_term.erase(ItemGroups)
        catalog -> :persistent_term.put(ItemGroups, catalog)
      end
    end)

    :ok
  end

  test "draw exhausts rate-specified copies and refills on the next draw" do
    install_group(:pool_exhaustion, [{501, 2}, {502, 1}])

    assert {:ok, first_cycle} = ItemGroupPool.draw(:pool_exhaustion, 0, 3)
    assert Enum.frequencies(first_cycle) == %{501 => 2, 502 => 1}

    assert {:ok, [refilled]} = ItemGroupPool.draw(:pool_exhaustion, 0, 1)
    assert refilled in [501, 502]
  end

  test "rollback returns drawn copies to the subgroup" do
    install_group(:pool_rollback, [{601, 2}, {602, 1}])
    assert {:ok, drawn} = ItemGroupPool.draw(:pool_rollback, 0, 3)

    assert :ok = ItemGroupPool.rollback(:pool_rollback, 0, drawn)
    assert {:ok, restored} = ItemGroupPool.draw(:pool_rollback, 0, 3)
    assert Enum.frequencies(restored) == %{601 => 2, 602 => 1}
  end

  test "concurrent draws do not over-issue the last copies" do
    install_group(:pool_concurrent, [{701, 1}, {702, 1}])

    drawn =
      1..2
      |> Task.async_stream(fn _ -> ItemGroupPool.draw(:pool_concurrent, 0, 1) end,
        ordered: false
      )
      |> Enum.flat_map(fn {:ok, {:ok, item_ids}} -> item_ids end)

    assert Enum.frequencies(drawn) == %{701 => 1, 702 => 1}
  end

  test "ensure_pool is idempotent and a timeout stops the transient owner" do
    install_group(:pool_lifecycle, [{801, 1}])

    owner = ItemGroupPool.ensure_pool(:pool_lifecycle)
    assert ItemGroupPool.ensure_pool(:pool_lifecycle) == owner

    monitor = Process.monitor(owner)
    send(owner, :timeout)

    assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}
    assert Horde.Registry.lookup(Cluster.registry(), {:item_group_pool, :pool_lifecycle}) == []
  end

  defp install_group(key, entries) do
    entries = Enum.map(entries, fn {item_id, rate} -> %Entry{item_id: item_id, rate: rate} end)
    subgroup = %SubGroup{number: 0, algorithm: :shared_pool, entries: entries}
    :persistent_term.put(ItemGroups, %{key => %Group{key: key, subgroups: [subgroup]}})
  end
end
