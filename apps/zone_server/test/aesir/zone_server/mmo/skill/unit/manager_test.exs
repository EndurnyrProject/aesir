defmodule Aesir.ZoneServer.Mmo.Skill.Unit.ManagerTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog
  import Mimic

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  setup :setup_ets_tables
  setup :verify_on_exit!

  defmodule FakeUnit do
    @behaviour Ground

    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    @impl Ground
    def on_place(%Group{center: center}) do
      {:ok, %{cells: [center], state: %{}, interval: 450, duration: 5_000}}
    end

    @impl Ground
    def on_interval(%Group{state: state} = group, _now) do
      if Map.get(state, :expire_now) do
        {:expire, group}
      else
        {:ok, %{group | state: Map.update(state, :ticks, 1, &(&1 + 1))}}
      end
    end

    @impl Ground
    def on_expire(%Group{group_id: group_id, state: state}) do
      if test_pid = state[:test_pid], do: send(test_pid, {:expired, group_id})
      :ok
    end
  end

  defmodule SerializedUnit do
    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    def on_touch(%Group{state: %{test_pid: test_pid}} = group, mover) do
      send(test_pid, {:touch_started, self()})

      receive do
        :release_touch -> :ok
      end

      {:ok,
       %{
         group
         | caster_id: 22,
           target_type: elem(mover, 0),
           target_id: elem(mover, 1),
           map_name: "geffen",
           cells: [{20, 20}],
           expires_at: 30_000,
           state: Map.put(group.state, :touched, true)
       }}
    end

    def on_interval(%Group{state: state} = group, _now) do
      {:ok, %{group | state: Map.put(state, :ticked_after_touch, state[:touched] == true)}}
    end

    def on_expire(_group), do: :ok
  end

  defmodule FailingUnit do
    def on_interval(_group, _now), do: raise("callback failed")
    def on_expire(_group), do: :ok
  end

  defmodule ForeignIdUnit do
    alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

    def on_interval(%Group{state: state} = group, _now) do
      updated = %{group | group_id: state.foreign_group_id, state: %{foreign: true}}

      case state.result do
        :ok -> {:ok, updated}
        :expire -> {:expire, updated}
      end
    end

    def on_expire(%Group{group_id: group_id, state: state}) do
      send(state.test_pid, {:expired, group_id})
      :ok
    end
  end

  setup do
    stub(Catalog, :ground_module_for, fn
      :fake_unit -> {:ok, FakeUnit}
      :serialized_unit -> {:ok, SerializedUnit}
      :failing_unit -> {:ok, FailingUnit}
      :foreign_id_unit -> {:ok, ForeignIdUnit}
    end)

    :ok
  end

  defp start_manager(now) do
    manager =
      start_supervised!(
        {Manager, name: nil, clock: fn -> now end, schedule_tick: fn _pid, _interval -> :ok end}
      )

    allow(Catalog, self(), manager)
    manager
  end

  defp group(group_id, attrs) do
    base = %Group{
      group_id: group_id,
      skill_id: 0,
      skill_name: :fake_unit,
      level: 1,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: 0,
      expires_at: 1_000_000,
      interval: 450,
      state: %{}
    }

    struct(base, attrs)
  end

  describe "tick/1" do
    test "runs only due groups, re-arms their deadline, and uses the injected clock" do
      now = 10_000
      manager = start_manager(now)
      :ok = Manager.register(manager, group(1, next_tick_at: now - 10, interval: 450))
      :ok = Manager.register(manager, group(2, next_tick_at: now + 500))

      assert :ok = Manager.tick(manager)

      assert %Group{next_tick_at: 10_450, state: %{ticks: 1}} = Storage.get(1)
      assert %Group{next_tick_at: 10_500, state: %{}} = Storage.get(2)
    end

    test "uses the reindexed deadline after an interval update" do
      now = 10_000
      manager = start_manager(now)
      :ok = Manager.register(manager, group(1, next_tick_at: now, interval: 450))

      assert :ok = Manager.tick(manager, now)
      assert :ok = Manager.tick(manager, now + 449)
      assert Storage.get(1).state[:ticks] == 1

      assert :ok = Manager.tick(manager, now + 450)
      assert Storage.get(1).state[:ticks] == 2
    end

    test "expires a due group at most once" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1,
            next_tick_at: now - 10,
            expires_at: now - 10,
            state: %{expire_now: true, test_pid: self()}
          )
        )

      assert :ok = Manager.tick(manager)

      assert_received {:expired, 1}
      refute_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "tears down a group when on_interval returns expire before its deadline" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1,
            next_tick_at: now,
            expires_at: now + 5_000,
            state: %{expire_now: true, test_pid: self()}
          )
        )

      assert :ok = Manager.tick(manager)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "runs expiry cleanup for a group that is not due for an interval" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1,
            next_tick_at: now + 5_000,
            expires_at: now,
            state: %{test_pid: self()}
          )
        )

      assert :ok = Manager.tick(manager)

      assert_received {:expired, 1}
      assert nil == Storage.get(1)
    end

    test "cleans only a callback's group and logs its skill and group identity" do
      now = 10_000
      manager = start_manager(now)

      :ok =
        Manager.register(
          manager,
          group(1, skill_name: :failing_unit, next_tick_at: now)
        )

      :ok = Manager.register(manager, group(2, next_tick_at: now))

      log = capture_log(fn -> assert :ok = Manager.tick(manager) end)

      assert log =~ "failing_unit"
      assert log =~ "group_id=1"
      assert nil == Storage.get(1)
      assert %Group{state: %{ticks: 1}} = Storage.get(2)
    end

    test "rejects an updated group with a foreign id without overwriting that group" do
      now = 10_000
      manager = start_manager(now)
      other = group(2, next_tick_at: now + 5_000, state: %{untouched: true})

      :ok =
        Manager.register(
          manager,
          group(1,
            skill_name: :foreign_id_unit,
            next_tick_at: now,
            state: %{
              result: :ok,
              foreign_group_id: other.group_id,
              test_pid: self()
            }
          )
        )

      :ok = Manager.register(manager, other)

      log = capture_log(fn -> assert :ok = Manager.tick(manager) end)

      assert log =~ "foreign_id_unit"
      assert log =~ "group_id=1"
      assert_received {:expired, 1}
      assert nil == Storage.get(1)
      assert ^other = Storage.get(2)
      assert [] == Storage.get_due_groups(now)
      assert [%Group{group_id: 2}] = Storage.get_due_groups(now + 5_000)
    end

    test "rejects an expired group with a foreign id without deleting that group" do
      now = 10_000
      manager = start_manager(now)
      other = group(2, next_tick_at: now + 5_000, state: %{untouched: true})

      :ok =
        Manager.register(
          manager,
          group(1,
            skill_name: :foreign_id_unit,
            next_tick_at: now,
            state: %{
              result: :expire,
              foreign_group_id: other.group_id,
              test_pid: self()
            }
          )
        )

      :ok = Manager.register(manager, other)

      log = capture_log(fn -> assert :ok = Manager.tick(manager) end)

      assert log =~ "foreign_id_unit"
      assert log =~ "group_id=1"
      assert_received {:expired, 1}
      assert nil == Storage.get(1)
      assert ^other = Storage.get(2)
      assert [] == Storage.get_due_groups(now)
      assert [%Group{group_id: 2}] = Storage.get_due_groups(now + 5_000)
    end
  end

  test "serializes a concurrent touch before a queued tick and keeps every index consistent" do
    now = 10_000
    manager = start_manager(now)

    :ok =
      Manager.register(
        manager,
        group(1,
          skill_name: :serialized_unit,
          next_tick_at: now,
          expires_at: 20_000,
          state: %{test_pid: self()}
        )
      )

    touch = Task.async(fn -> Manager.trigger(manager, 1, {:player, 99}, :on_touch) end)
    assert_receive {:touch_started, ^manager}

    tick = Task.async(fn -> Manager.tick(manager) end)
    send(manager, :release_touch)

    assert :ok = Task.await(touch)
    assert :ok = Task.await(tick)

    assert %Group{
             caster_type: :player,
             caster_id: 22,
             target_type: :player,
             target_id: 99,
             map_name: "geffen",
             cells: [{20, 20}],
             next_tick_at: 10_450,
             expires_at: 30_000,
             state: %{ticked_after_touch: true}
           } = Storage.get(1)

    assert [] == Storage.get_groups_at_cell("prontera", 100, 100)
    assert [] == Storage.get_groups_by_caster(:player, 1)
    assert [] == Storage.get_expired_groups(20_000)
    assert [%Group{group_id: 1}] = Storage.get_groups_at_cell("geffen", 20, 20)
    assert [%Group{group_id: 1}] = Storage.get_groups_by_caster(:player, 22)
    assert [%Group{group_id: 1}] = Storage.get_groups_by_target(:player, 99)
    assert [%Group{group_id: 1}] = Storage.get_due_groups(10_450)
    assert [%Group{group_id: 1}] = Storage.get_expired_groups(30_000)
  end

  test "serializes concurrent delete and late update without resurrecting any index" do
    manager = start_manager(10_000)

    :ok =
      Manager.register(
        manager,
        group(1, target_type: :mob, target_id: 33, next_tick_at: 20_000, expires_at: 30_000)
      )

    delete = Task.async(fn -> Manager.destroy(manager, 1) end)
    update = Task.async(fn -> Manager.update_state(manager, 1, %{late: true}) end)

    assert :ok = Task.await(delete)
    assert :ok = Task.await(update)
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
end
