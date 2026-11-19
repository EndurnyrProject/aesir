defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPoolTest do
  use ExUnit.Case, async: false

  import Aesir.ZoneServer.Factory

  alias Aesir.Commons.Cluster
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool

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
    key = install_group([{501, 2}, {502, 1}])

    assert {:ok, first_cycle} = ItemGroupPool.draw(key, 0, 3)
    assert Enum.frequencies(first_cycle) == %{501 => 2, 502 => 1}

    assert {:ok, [refilled]} = ItemGroupPool.draw(key, 0, 1)
    assert refilled in [501, 502]
  end

  test "rollback returns drawn copies to the subgroup" do
    key = install_group([{601, 2}, {602, 1}])
    assert {:ok, drawn} = ItemGroupPool.draw(key, 0, 3)

    assert :ok = ItemGroupPool.rollback(key, 0, drawn)
    assert {:ok, restored} = ItemGroupPool.draw(key, 0, 3)
    assert Enum.frequencies(restored) == %{601 => 2, 602 => 1}
  end

  test "concurrent draws do not over-issue the last copies" do
    key = install_group([{701, 1}, {702, 1}])

    drawn =
      1..2
      |> Task.async_stream(fn _ -> ItemGroupPool.draw(key, 0, 1) end, ordered: false)
      |> Enum.flat_map(fn {:ok, {:ok, item_ids}} -> item_ids end)

    assert Enum.frequencies(drawn) == %{701 => 1, 702 => 1}
  end

  test "ensure_pool is idempotent and a timeout stops the transient owner" do
    key = install_group([{801, 1}])

    owner = ItemGroupPool.ensure_pool(key)
    assert ItemGroupPool.ensure_pool(key) == owner

    monitor = Process.monitor(owner)
    send(owner, :timeout)

    assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}
    assert Horde.Registry.lookup(Cluster.registry(), {:item_group_pool, key}) == []
  end

  defp install_group(entries) do
    entries =
      Enum.map(entries, fn {id, rate} -> build(:item_group_entry, item_id: id, rate: rate) end)

    subgroup = build(:item_subgroup, number: 0, algorithm: :shared_pool, entries: entries)
    group = build(:item_group, subgroups: [subgroup])
    :persistent_term.put(ItemGroups, %{group.key => group})
    group.key
  end
end
