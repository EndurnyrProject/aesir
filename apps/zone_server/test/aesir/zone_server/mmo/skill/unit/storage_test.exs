defmodule Aesir.ZoneServer.Mmo.Skill.Unit.StorageTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  setup :setup_ets_tables

  defp group(group_id, attrs \\ []) do
    base = %Group{
      group_id: group_id,
      skill_id: 89,
      skill_name: :wz_stormgust,
      level: 10,
      caster_id: 2000,
      caster_type: :player,
      map_name: "prontera",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 450,
      state: %{}
    }

    struct(base, attrs)
  end

  test "a group carries bounded caster and target lifecycle actions" do
    policy = %LifecyclePolicy{
      on_caster_loss: :skip_action,
      on_target_loss: :expire
    }

    assert %Group{
             lifecycle_policy: ^policy,
             target_type: :mob,
             target_id: 3000,
             visible?: true,
             created_at: 100
           } =
             group(1,
               lifecycle_policy: policy,
               target_type: :mob,
               target_id: 3000,
               visible?: true,
               created_at: 100
             )
  end

  describe "insert/1 and get/1" do
    test "round-trips a group" do
      g = group(1)

      assert :ok = Storage.insert(g)
      assert ^g = Storage.get(1)
    end

    test "get/1 returns nil for an unknown group_id" do
      assert nil == Storage.get(999)
    end

    test "replacing a group through insert/1 removes its old secondary keys" do
      :ok = Storage.insert(group(1, target_type: :mob, target_id: 3000))

      :ok =
        Storage.insert(
          group(1,
            map_name: "geffen",
            cells: [{20, 20}],
            caster_id: 4000,
            target_type: nil,
            target_id: nil
          )
        )

      assert [] == Storage.get_groups_at_cell("prontera", 100, 100)
      assert [] == Storage.get_groups_by_caster(:player, 2000)
      assert [] == Storage.get_groups_by_target(:mob, 3000)
      assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("geffen", 20, 20)
    end
  end

  describe "delete/1" do
    test "removes a stored group" do
      :ok = Storage.insert(group(1))

      assert :ok = Storage.delete(1)
      assert nil == Storage.get(1)
    end

    test "repeated delete and a late update leave no primary or secondary keys" do
      original = group(1, target_type: :mob, target_id: 3000)
      :ok = Storage.insert(original)

      assert :ok = Storage.delete(1)
      assert :ok = Storage.delete(1)
      assert :ok = Storage.update(%{original | cells: [{20, 20}]})
      assert nil == Storage.get(1)

      for table <- [
            :skill_unit_coordinate_index,
            :skill_unit_due_index,
            :skill_unit_expiry_index,
            :skill_unit_caster_index,
            :skill_unit_target_index
          ] do
        assert [] == :ets.tab2list(EtsTable.table_for(table))
      end
    end

    test "removes cells through the group-cell index" do
      cell = %Cell{
        cell_id: 5,
        group_id: 1,
        map_name: "prontera",
        x: 100,
        y: 101,
        flags: Cell.visible()
      }

      :ok = Storage.insert(group(1))
      :ok = Storage.insert_cell(cell)

      assert :ok = Storage.delete(1)
      assert nil == Storage.get_cell(cell.cell_id)
      assert [] == Storage.get_cells_by_group(1)
      assert [] == :ets.tab2list(EtsTable.table_for(:skill_unit_group_cells_index))
    end
  end

  describe "all/0" do
    test "returns every stored group" do
      :ok = Storage.insert(group(1))
      :ok = Storage.insert(group(2))

      ids = Storage.all() |> Enum.map(& &1.group_id) |> Enum.sort()

      assert ids == [1, 2]
    end
  end

  describe "update/1" do
    test "replaces an existing group" do
      :ok = Storage.insert(group(1, state: %{hit_counts: %{}}))

      :ok = Storage.update(group(1, state: %{hit_counts: %{5 => 3}}))

      assert %Group{state: %{hit_counts: %{5 => 3}}} = Storage.get(1)
    end

    test "moves every secondary key when indexed fields change" do
      :ok =
        Storage.insert(
          group(1,
            next_tick_at: 100,
            expires_at: 200,
            target_type: :mob,
            target_id: 3000
          )
        )

      :ok =
        Storage.update(
          group(1,
            caster_type: :mob,
            caster_id: 4000,
            target_type: :player,
            target_id: 5000,
            map_name: "geffen",
            cells: [{20, 20}],
            next_tick_at: 300,
            expires_at: 400
          )
        )

      assert [] == Storage.get_groups_at_cell("prontera", 100, 100)
      assert [] == Storage.get_groups_by_caster(:player, 2000)
      assert [] == Storage.get_groups_by_target(:mob, 3000)
      assert [] == Storage.get_due_groups(250)
      assert [] == Storage.get_expired_groups(350)

      assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("geffen", 20, 20)
      assert [%Group{group_id: 1}] = Storage.get_groups_by_caster(:mob, 4000)
      assert [%Group{group_id: 1}] = Storage.get_groups_by_target(:player, 5000)
      assert [%Group{group_id: 1}] = Storage.get_due_groups(300)
      assert [%Group{group_id: 1}] = Storage.get_expired_groups(400)
    end
  end

  describe "get_due_groups/1" do
    test "returns only groups whose next_tick_at <= now" do
      now = 1_000

      :ok = Storage.insert(group(1, next_tick_at: now - 10))
      :ok = Storage.insert(group(2, next_tick_at: now))
      :ok = Storage.insert(group(3, next_tick_at: now + 10))

      ids = Storage.get_due_groups(now) |> Enum.map(& &1.group_id) |> Enum.sort()

      assert ids == [1, 2]
    end
  end

  test "coordinate and timing queries use secondary indexes instead of scanning groups" do
    unindexed = group(99, cells: [{100, 100}], next_tick_at: 0, expires_at: 0)
    :ets.insert(EtsTable.table_for(:skill_units), {99, unindexed})

    assert [] == Storage.get_groups_at_cell("prontera", 100, 100)
    assert [] == Storage.get_due_groups(100)
    assert [] == Storage.get_expired_groups(100)
  end

  test "skill-and-caster lookup uses the caster index and filters by skill" do
    :ok = Storage.insert(group(1, skill_name: :wz_quagmire, caster_id: 100))
    :ok = Storage.insert(group(2, skill_name: :al_warp, caster_id: 100))
    :ok = Storage.insert(group(3, skill_name: :wz_quagmire, caster_id: 200))

    unindexed = group(4, skill_name: :wz_quagmire, caster_id: 100)
    :ets.insert(EtsTable.table_for(:skill_units), {4, unindexed})

    assert [%Group{group_id: 1}] =
             Storage.get_groups_by_skill_and_caster(:wz_quagmire, :player, 100)
  end

  describe "get_expired_groups/1" do
    test "returns only groups whose expires_at <= now" do
      now = 1_000

      :ok = Storage.insert(group(1, expires_at: now - 10))
      :ok = Storage.insert(group(2, expires_at: now))
      :ok = Storage.insert(group(3, expires_at: now + 10))

      ids = Storage.get_expired_groups(now) |> Enum.map(& &1.group_id) |> Enum.sort()

      assert ids == [1, 2]
    end
  end

  describe "get_groups_at_cell/3" do
    test "returns groups whose footprint covers the cell on that map" do
      :ok = Storage.insert(group(1, cells: [{100, 100}]))

      assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("prontera", 100, 100)
    end

    test "returns [] when no footprint covers the cell" do
      :ok = Storage.insert(group(1, cells: [{100, 100}]))

      assert [] == Storage.get_groups_at_cell("prontera", 50, 50)
    end

    test "is scoped to the map and ignores groups on other maps" do
      :ok = Storage.insert(group(1, map_name: "geffen", cells: [{100, 100}]))

      assert [] == Storage.get_groups_at_cell("prontera", 100, 100)
    end

    test "returns every group stacked on the same cell" do
      :ok = Storage.insert(group(1, cells: [{100, 100}]))
      :ok = Storage.insert(group(2, cells: [{99, 100}, {100, 100}, {101, 100}]))

      ids =
        Storage.get_groups_at_cell("prontera", 100, 100)
        |> Enum.map(& &1.group_id)
        |> Enum.sort()

      assert ids == [1, 2]
    end

    test "matches any cell of a multi-cell footprint" do
      :ok = Storage.insert(group(1, cells: [{10, 10}, {11, 10}, {12, 10}]))

      assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("prontera", 11, 10)
      assert [] == Storage.get_groups_at_cell("prontera", 13, 10)
    end
  end

  describe "get_visible_groups_in_range/4" do
    test "returns visible groups intersecting the range in group ID order" do
      :ok = Storage.insert(group(3, visible?: true, cells: [{100, 100}]))
      :ok = Storage.insert(group(1, visible?: true, cells: [{101, 100}]))
      :ok = Storage.insert(group(2, visible?: false, cells: [{100, 100}]))
      :ok = Storage.insert(group(4, visible?: true, cells: [{102, 100}]))

      assert [%Group{group_id: 1}, %Group{group_id: 3}] =
               Storage.get_visible_groups_in_range("prontera", 100, 100, 1)
    end
  end

  describe "caster and target queries" do
    test "returns groups through their caster and optional target identities" do
      :ok = Storage.insert(group(1, target_type: :mob, target_id: 3000))
      :ok = Storage.insert(group(2))

      :ok =
        Storage.insert(
          group(3,
            caster_type: :mob,
            caster_id: 4000,
            target_type: :player,
            target_id: 5000
          )
        )

      caster_ids =
        Storage.get_groups_by_caster(:player, 2000)
        |> Enum.map(& &1.group_id)
        |> Enum.sort()

      assert caster_ids == [1, 2]
      assert [%Group{group_id: 1}] = Storage.get_groups_by_target(:mob, 3000)
      assert [] == Storage.get_groups_by_target(:mob, 9999)
    end
  end

  test "indexes cells by id and group" do
    cell = %Cell{
      cell_id: 5,
      group_id: 1,
      map_name: "prontera",
      x: 100,
      y: 101,
      flags: Cell.visible()
    }

    :ok = Storage.insert_cell(cell)

    assert ^cell = Storage.get_cell(5)
    assert [^cell] = Storage.get_cells_by_group(1)

    assert :ok = Storage.delete_cell(5)
    assert nil == Storage.get_cell(5)
    assert [] == Storage.get_cells_by_group(1)
  end

  test "moves group membership only when a stored cell changes owner" do
    cell = %Cell{
      cell_id: 5,
      group_id: 1,
      map_name: "prontera",
      x: 100,
      y: 101,
      flags: Cell.visible()
    }

    :ok = Storage.insert_cell(cell)
    :ok = Storage.update_cell(%{cell | group_id: 2})

    assert [] == Storage.get_cells_by_group(1)
    assert [%Cell{cell_id: 5, group_id: 2}] = Storage.get_cells_by_group(2)
  end
end
