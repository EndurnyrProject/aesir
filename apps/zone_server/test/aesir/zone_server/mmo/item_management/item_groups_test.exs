defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroupsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Loader

  @group_yaml """
  - key: test_group
    subgroups:
      - algorithm: random
        number: 2
        entries:
          - item_id: 12345
            rate: 10
            amount: 3
            identify: true
            duration: 60
            bound: account
            unique_id: true
            refine_minimum: 4
            refine_maximum: 7
            grade_minimum: 1
            grade_maximum: 3
            named: true
            announced: true
  """

  setup context do
    :persistent_term.erase(ItemGroups)
    on_exit(fn -> :persistent_term.erase(ItemGroups) end)
    Aesir.ZoneServer.DbTestSetup.configure_root(context, "item_groups")
  end

  test "fetch resolves the ORE group from the runtime catalog" do
    assert {:ok, %Group{key: :ore, subgroups: [subgroup]}} = ItemGroups.fetch(:ore)
    assert subgroup.number == 1
    assert subgroup.algorithm == :shared_pool
    assert Enum.any?(subgroup.entries, &(&1.item_id == 1002 and &1.rate == 30))
    assert :error = ItemGroups.fetch(:does_not_exist)
  end

  test "reload replaces the persistent catalog" do
    :persistent_term.put(ItemGroups, %{})
    assert :error = ItemGroups.fetch(:ore)

    assert :ok = ItemGroups.reload()
    assert {:ok, %Group{key: :ore}} = ItemGroups.fetch(:ore)
  end

  @tag :tmp_dir
  test "loader maps every supported entry attribute and defaults", %{tmp_dir: dir} do
    write_yaml(dir, @group_yaml)

    assert %{
             test_group: %Group{
               subgroups: [
                 %{
                   entries: [
                     %Entry{
                       item_id: 12_345,
                       rate: 10,
                       amount: 3,
                       identify?: true,
                       duration_min: 60,
                       bound: :account,
                       unique_id?: true,
                       refine_min: 4,
                       refine_max: 7,
                       grade_min: 1,
                       grade_max: 3,
                       named?: true,
                       announced?: true
                     }
                   ]
                 }
               ]
             }
           } = Loader.load()

    write_yaml(dir, """
    - key: defaults
      subgroups:
        - algorithm: all
          number: 0
          entries:
            - item_id: 501
    """)

    File.rm_rf!(Path.join(dir, ".cache"))

    assert %{defaults: %Group{subgroups: [%{entries: [%Entry{} = entry]}]}} = Loader.load()
    assert entry.rate == 0
    assert entry.amount == 1
    refute entry.identify?
    assert entry.duration_min == 0
  end

  @tag :tmp_dir
  test "loader reuses a fresh ETF cache", %{tmp_dir: dir} do
    yaml = write_yaml(dir, @group_yaml)
    assert %{test_group: %Group{}} = Loader.load()

    cache = Path.join([dir, ".cache", "item_groups_v1.etf"])
    File.write!(yaml, String.replace(@group_yaml, "test_group", "changed_group"))
    File.touch!(yaml, 1_000_000)
    File.touch!(cache, 2_000_000)

    assert %{test_group: %Group{}} = Loader.load()
  end

  @tag :tmp_dir
  test "loader rebuilds when YAML is newer than the ETF cache", %{tmp_dir: dir} do
    yaml = write_yaml(dir, @group_yaml)
    assert %{test_group: %Group{}} = Loader.load()

    cache = Path.join([dir, ".cache", "item_groups_v1.etf"])
    File.write!(yaml, String.replace(@group_yaml, "test_group", "changed_group"))
    File.touch!(cache, 1_000_000)
    File.touch!(yaml, 2_000_000)

    assert %{changed_group: %Group{}} = Loader.load()
  end

  defp write_yaml(dir, contents) do
    path = Path.join(dir, "item_groups.yml")
    File.write!(path, contents)
    path
  end
end
