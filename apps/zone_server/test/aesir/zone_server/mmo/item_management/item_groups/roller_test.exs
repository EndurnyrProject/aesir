defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.RollerTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.Cluster
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller
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

  test "roll_full includes every entry from all subgroups" do
    group =
      group(:all_group, [%SubGroup{number: 0, algorithm: :all, entries: [entry(501), entry(502)]}])

    assert group |> Roller.roll_full(fn _max -> 1 end) |> Enum.map(& &1.item_id) == [501, 502]
  end

  test "roll_full includes one weighted grant from each random subgroup" do
    group =
      group(:full_random_group, [
        %SubGroup{number: 0, algorithm: :all, entries: [entry(701)]},
        %SubGroup{
          number: 1,
          algorithm: :random,
          entries: [entry(702, rate: 1), entry(703, rate: 2)]
        },
        %SubGroup{number: 2, algorithm: :random, entries: [entry(704, rate: 1)]}
      ])

    assert group |> Roller.roll_full(fn max -> max end) |> Enum.map(& &1.item_id) == [
             701,
             703,
             704
           ]
  end

  test "pick_id uses catalog weights without starting or depleting a shared pool" do
    subgroup = %SubGroup{
      number: 3,
      algorithm: :shared_pool,
      entries: [entry(801, rate: 1), entry(802, rate: 2)]
    }

    group = group(:non_depleting_pick, [subgroup])
    registry_key = {:item_group_pool, group.key}

    assert Horde.Registry.lookup(Cluster.registry(), registry_key) == []
    assert Roller.pick_id(group, 3, fn max -> max end) == {:ok, 802}
    assert Horde.Registry.lookup(Cluster.registry(), registry_key) == []
  end

  test "roll_full draws one grant from a shared-pool subgroup" do
    subgroup = %SubGroup{
      number: 5,
      algorithm: :shared_pool,
      entries: [entry(850, rate: 1)]
    }

    group = group(:roller_full_shared_pool, [subgroup])
    :persistent_term.put(ItemGroups, %{group.key => group})

    assert [%{item_id: 850, drawn: {5, [850]}}] = Roller.roll_full(group, fn _max -> 1 end)

    owner = ItemGroupPool.ensure_pool(group.key)
    on_exit(fn -> if Process.alive?(owner), do: send(owner, :timeout) end)
  end

  test "roll_n delegates shared-pool draws, refills, and marks each copy for rollback" do
    subgroup = %SubGroup{
      number: 4,
      algorithm: :shared_pool,
      entries: [
        entry(901, rate: 1, refine_min: 2, refine_max: 4, grade_min: 1, grade_max: 3),
        entry(902, rate: 2, refine_min: 2, refine_max: 4, grade_min: 1, grade_max: 3)
      ]
    }

    group = group(:roller_shared_pool, [subgroup])
    :persistent_term.put(ItemGroups, %{group.key => group})

    grants = Roller.roll_n(group, 4, 5, fn max -> max end)

    assert length(grants) == 5
    assert Enum.all?(grants, &(&1.item_id in [901, 902]))
    assert Enum.all?(grants, &(&1.drawn == {4, [&1.item_id]}))
    assert Enum.all?(grants, &(&1.refine in 2..4 and &1.grade in 1..3))

    owner = ItemGroupPool.ensure_pool(group.key)
    on_exit(fn -> if Process.alive?(owner), do: send(owner, :timeout) end)
  end

  test "roll_n samples an all subgroup when a count is requested" do
    subgroup = %SubGroup{
      number: 6,
      algorithm: :all,
      entries: [entry(951, rate: 1), entry(952, rate: 2)]
    }

    grants = Roller.roll_n(group(:sampled_all, [subgroup]), 6, 3, fn max -> max end)

    assert Enum.map(grants, & &1.item_id) == [952, 952, 952]
  end

  test "roll_n copies entry attributes and rolls refine and grade" do
    selected =
      entry(960,
        rate: 1,
        amount: 3,
        identify?: true,
        duration_min: 10,
        bound: :account,
        unique_id?: true,
        refine_min: 2,
        refine_max: 4,
        grade_min: 1,
        grade_max: 3,
        named?: true,
        announced?: true
      )

    subgroup = %SubGroup{number: 7, algorithm: :random, entries: [selected]}

    assert [grant] = Roller.roll_n(group(:attribute_group, [subgroup]), 7, 1, fn max -> max end)

    assert grant == %{
             item_id: 960,
             amount: 3,
             identify?: true,
             refine: 4,
             grade: 3,
             bound: :account,
             unique_id?: true,
             duration_min: 10,
             named?: true,
             announced?: true,
             drawn: nil
           }
  end

  test "roll_n makes weighted picks from a random subgroup" do
    subgroup = %SubGroup{
      number: 1,
      algorithm: :random,
      entries: [entry(601, rate: 1), entry(602, rate: 3)]
    }

    group = group(:weighted_group, [subgroup])

    assert [%{item_id: 601}] = Roller.roll_n(group, 1, 1, fn _max -> 1 end)
    assert [%{item_id: 602}] = Roller.roll_n(group, 1, 1, fn max -> max end)
  end

  defp group(key, subgroups), do: %Group{key: key, subgroups: subgroups}
  defp entry(item_id, attrs \\ []), do: struct!(Entry, Keyword.put(attrs, :item_id, item_id))
end
