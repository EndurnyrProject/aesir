defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.RollerTest do
  use ExUnit.Case, async: false

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller

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

  test "roll_full grants every all entry and one weighted grant from each random subgroup" do
    group =
      build(:item_group,
        subgroups: [
          build(:item_subgroup, number: 0, algorithm: :all, entries: [entry(701), entry(705)]),
          build(:item_subgroup,
            number: 1,
            algorithm: :random,
            entries: [entry(702, rate: 1), entry(703, rate: 2)]
          ),
          build(:item_subgroup, number: 2, algorithm: :random, entries: [entry(704, rate: 1)])
        ]
      )

    assert group |> Roller.roll_full(fn max -> max end) |> Enum.map(& &1.item_id) == [
             701,
             705,
             703,
             704
           ]
  end

  test "pick_grant picks one entry and uses the requested quantity" do
    group =
      build(:item_group,
        subgroups: [
          build(:item_subgroup,
            number: 1,
            algorithm: :random,
            entries: [entry(901, rate: 1), entry(902, rate: 1)]
          )
        ]
      )

    assert %{item_id: item_id, amount: 5, identify?: false, refine: 0, bound: nil} =
             Roller.pick_grant(group, 1, 5, rng: fn _max -> 1 end)

    assert item_id in [901, 902]
  end

  test "pick_grant carries the identify request" do
    subgroup =
      build(:item_subgroup, number: 1, algorithm: :random, entries: [entry(904, rate: 1)])

    group = build(:item_group, subgroups: [subgroup])

    assert %{item_id: 904, identify?: true} =
             Roller.pick_grant(group, 1, 1, identify?: true, rng: fn _max -> 1 end)
  end

  test "pick_grant with quantity zero uses the entry's own amount" do
    group =
      build(:item_group,
        subgroups: [
          build(:item_subgroup, number: 2, algorithm: :all, entries: [entry(903, amount: 7)])
        ]
      )

    assert %{item_id: 903, amount: 7} = Roller.pick_grant(group, 2, 0, rng: fn _max -> 1 end)
  end

  test "pick_grant consumes one shared-pool copy" do
    subgroup =
      build(:item_subgroup, number: 5, algorithm: :shared_pool, entries: [entry(850, rate: 1)])

    group = build(:item_group, subgroups: [subgroup])

    :persistent_term.put(ItemGroups, %{group.key => group})

    assert %{item_id: 850, amount: 2, drawn: {5, [850]}} =
             Roller.pick_grant(group, 5, 2)

    owner = ItemGroupPool.ensure_pool(group.key)
    assert %{5 => %{}} = :sys.get_state(owner).subs
    on_exit(fn -> if Process.alive?(owner), do: send(owner, :timeout) end)
  end

  test "pick_grant returns nil for a missing subgroup" do
    subgroup = build(:item_subgroup, number: 1, algorithm: :random, entries: [entry(501)])
    group = build(:item_group, subgroups: [subgroup])

    assert Roller.pick_grant(group, 9, 1) == nil
  end

  test "pick_id is algorithm-aware and consumes a shared-pool copy" do
    subgroup =
      build(:item_subgroup, number: 3, algorithm: :shared_pool, entries: [entry(801, rate: 2)])

    group = build(:item_group, subgroups: [subgroup])

    :persistent_term.put(ItemGroups, %{group.key => group})

    assert Roller.pick_id(group, 3) == {:ok, 801}

    owner = ItemGroupPool.ensure_pool(group.key)
    assert %{3 => %{801 => 1}} = :sys.get_state(owner).subs
    on_exit(fn -> if Process.alive?(owner), do: send(owner, :timeout) end)
  end

  test "pick_id uses the random subgroup weights" do
    group =
      build(:item_group,
        subgroups: [
          build(:item_subgroup,
            number: 1,
            algorithm: :random,
            entries: [entry(601, rate: 1), entry(602, rate: 3)]
          )
        ]
      )

    assert Roller.pick_id(group, 1, fn _max -> 1 end) == {:ok, 601}
    assert Roller.pick_id(group, 1, fn max -> max end) == {:ok, 602}
  end

  test "roll_full draws one grant from a shared-pool subgroup" do
    subgroup =
      build(:item_subgroup, number: 5, algorithm: :shared_pool, entries: [entry(850, rate: 1)])

    group = build(:item_group, subgroups: [subgroup])

    :persistent_term.put(ItemGroups, %{group.key => group})

    assert [%{item_id: 850, drawn: {5, [850]}}] = Roller.roll_full(group, fn _max -> 1 end)

    owner = ItemGroupPool.ensure_pool(group.key)
    on_exit(fn -> if Process.alive?(owner), do: send(owner, :timeout) end)
  end

  test "roll_n delegates shared-pool draws, refills, and marks each copy for rollback" do
    ranges = [refine_min: 2, refine_max: 4, grade_min: 1, grade_max: 3]

    subgroup =
      build(:item_subgroup,
        number: 4,
        algorithm: :shared_pool,
        entries: [entry(901, [rate: 1] ++ ranges), entry(902, [rate: 2] ++ ranges)]
      )

    group = build(:item_group, subgroups: [subgroup])
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
    subgroup =
      build(:item_subgroup,
        number: 6,
        algorithm: :all,
        entries: [entry(951, rate: 1), entry(952, rate: 2)]
      )

    grants = Roller.roll_n(build(:item_group, subgroups: [subgroup]), 6, 3, fn max -> max end)

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
        announced?: true,
        stacked?: false
      )

    subgroup = build(:item_subgroup, number: 7, algorithm: :random, entries: [selected])
    group = build(:item_group, subgroups: [subgroup])

    assert [grant] = Roller.roll_n(group, 7, 1, fn max -> max end)

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
             stacked?: false,
             refine_min: 2,
             refine_max: 4,
             grade_min: 1,
             grade_max: 3,
             random_option_group: nil,
             drawn: nil
           }
  end

  defp entry(item_id, attrs \\ []),
    do: build(:item_group_entry, Keyword.put(attrs, :item_id, item_id))
end
