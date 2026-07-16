defmodule Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupportTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex

  defmodule StationaryField do
    def field_support(_group),
      do: %{status_type: :sc_quagmire, params: [level: 2, val2: 10], target?: fn _ -> true end}

    def on_interval(group, _now), do: {:ok, group}
  end

  defmodule CombatOnlyField do
    def field_support(_group),
      do: %{status_type: :sc_quagmire, params: [level: 1, val2: 5], target?: &combat_target?/1}

    def on_interval(group, _now), do: {:ok, group}

    defp combat_target?({unit_type, _unit_id}) when unit_type in [:player, :mob], do: true
  end

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(Interpreter)

    stub(Interpreter, :remove_status, fn unit_type, unit_id, status_type ->
      StatusStorage.remove_status(unit_type, unit_id, status_type)
      :ok
    end)

    :ok
  end

  test "duplicate acquisition is idempotent and the strongest source wins" do
    test_pid = self()

    stub(Interpreter, :apply_status, fn :player, 7, :sc_quagmire, params ->
      send(test_pid, {:apply, params})
      StatusStorage.apply_status(:player, 7, :sc_quagmire, params)
      :ok
    end)

    params = [level: 1, val2: 5]
    assert :ok = FieldSupport.acquire(:player, 7, :sc_quagmire, 10, params)
    assert :ok = FieldSupport.acquire(:player, 7, :sc_quagmire, 10, params)
    assert :ok = FieldSupport.acquire(:player, 7, :sc_quagmire, 11, level: 5, val2: 25)

    assert FieldSupport.sources(:player, 7, :sc_quagmire) |> length() == 2
    assert_received {:apply, first_apply}
    assert first_apply[:level] == 1 and first_apply[:duration] == 0
    assert_received {:apply, second_apply}
    assert second_apply[:level] == 5 and second_apply[:duration] == 0
    refute_received {:apply, _}
  end

  test "reconciliation restores a materialized status that disappeared" do
    test_pid = self()

    stub(Interpreter, :apply_status, fn unit_type, unit_id, status_type, params ->
      send(test_pid, {:apply, params})
      StatusStorage.apply_status(unit_type, unit_id, status_type, params)
      :ok
    end)

    stub(Interpreter, :remove_status, fn unit_type, unit_id, status_type ->
      StatusStorage.remove_status(unit_type, unit_id, status_type)
      :ok
    end)

    assert :ok = FieldSupport.acquire(:player, 8, :sc_quagmire, 30, level: 2, val2: 10)
    :ok = StatusStorage.remove_status(:player, 8, :sc_quagmire)
    assert :ok = FieldSupport.acquire(:player, 8, :sc_quagmire, 30, level: 2, val2: 10)
    assert_received {:apply, restored}
    assert restored[:level] == 2 and restored[:duration] == 0
  end

  test "overlap refresh removes the owned status before reapplying changed parameters" do
    test_pid = self()

    stub(Interpreter, :apply_status, fn unit_type, unit_id, status_type, params ->
      StatusStorage.apply_status(unit_type, unit_id, status_type, params)
      send(test_pid, {:applied, params})
      :ok
    end)

    assert :ok = FieldSupport.acquire(:player, 12, :sc_quagmire, 60, level: 1, val2: 5)
    assert :ok = FieldSupport.acquire(:player, 12, :sc_quagmire, 61, level: 5, val2: 25)

    assert_received {:applied, first_apply}
    assert first_apply[:level] == 1
    assert_received {:applied, refreshed}
    assert refreshed[:level] == 5 and refreshed[:duration] == 0
  end

  test "releasing one source retains the status and the last release removes it" do
    test_pid = self()

    stub(Interpreter, :apply_status, fn _, _, _, params ->
      send(test_pid, {:apply, params})
      StatusStorage.apply_status(:mob, 3, :sc_quagmire, params)
      :ok
    end)

    stub(Interpreter, :remove_status, fn unit_type, unit_id, status_type ->
      send(test_pid, {:remove, unit_type, unit_id, status_type})
      :ok
    end)

    assert :ok = FieldSupport.acquire(:mob, 3, :sc_quagmire, 20, level: 2, val2: 10)
    assert :ok = FieldSupport.acquire(:mob, 3, :sc_quagmire, 21, level: 4, val2: 20)
    assert :ok = FieldSupport.release(:mob, 3, :sc_quagmire, 20)

    assert FieldSupport.supported?(:mob, 3, :sc_quagmire)
    assert_received {:apply, _initial}
    assert_received {:apply, refreshed}
    assert refreshed[:level] == 4 and refreshed[:duration] == 0

    assert :ok = FieldSupport.release(:mob, 3, :sc_quagmire, 21)
    refute FieldSupport.supported?(:mob, 3, :sc_quagmire)
    assert_received {:remove, :mob, 3, :sc_quagmire}
  end

  test "releasing the last field source preserves an independently owned status" do
    test_pid = self()

    stub(Interpreter, :apply_status, fn unit_type, unit_id, status_type, params ->
      StatusStorage.apply_status(unit_type, unit_id, status_type, params)
      :ok
    end)

    stub(Interpreter, :remove_status, fn unit_type, unit_id, status_type ->
      send(test_pid, {:remove, unit_type, unit_id, status_type})
      :ok
    end)

    assert :ok = FieldSupport.acquire(:player, 9, :sc_quagmire, 40, level: 1, val2: 5)
    :ok = StatusStorage.apply_status(:player, 9, :sc_quagmire, state: %{ordinary: true})
    assert :ok = FieldSupport.release(:player, 9, :sc_quagmire, 40)

    refute_received {:remove, :player, 9, :sc_quagmire}
    refute FieldSupport.field_owned?(:player, 9, :sc_quagmire)
  end

  test "release_group is idempotent and only removes its own sources" do
    test_pid = self()

    stub(Interpreter, :apply_status, fn unit_type, unit_id, status_type, params ->
      StatusStorage.apply_status(unit_type, unit_id, status_type, params)
      :ok
    end)

    stub(Interpreter, :remove_status, fn unit_type, unit_id, status_type ->
      send(test_pid, {:remove, unit_type, unit_id, status_type})
      StatusStorage.remove_status(unit_type, unit_id, status_type)
      :ok
    end)

    assert :ok = FieldSupport.acquire(:player, 10, :sc_quagmire, 50, level: 1, val2: 5)
    assert :ok = FieldSupport.acquire(:player, 10, :sc_quagmire, 51, level: 2, val2: 10)
    assert :ok = FieldSupport.release_group(50)
    assert FieldSupport.supported?(:player, 10, :sc_quagmire)
    assert :ok = FieldSupport.release_group(50)
    assert :ok = FieldSupport.release_group(51)
    assert_received {:remove, :player, 10, :sc_quagmire}
  end

  test "manager registration seeds stationary occupants and reconciliation restores support" do
    test_pid = self()
    Mimic.copy(Catalog)
    Mimic.copy(SpatialIndex)
    Mimic.copy(Interpreter)

    stub(Catalog, :ground_module_for, fn :stationary_field -> {:ok, StationaryField} end)
    stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 5, 5, 0 -> [{:player, 11}] end)

    stub(Interpreter, :apply_status, fn unit_type, unit_id, status_type, params ->
      send(test_pid, {:apply, params})
      StatusStorage.apply_status(unit_type, unit_id, status_type, params)
      :ok
    end)

    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    allow(Catalog, self(), manager)
    allow(SpatialIndex, self(), manager)
    allow(Interpreter, self(), manager)

    group = %Group{
      group_id: 99,
      skill_id: 999,
      skill_name: :stationary_field,
      level: 2,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: {5, 5},
      cells: [{5, 5}],
      next_tick_at: 1_000,
      expires_at: System.monotonic_time(:millisecond) + 100_000,
      interval: 1_000
    }

    assert :ok = Manager.register(manager, group)
    assert FieldSupport.supported?(:player, 11, :sc_quagmire)
  end

  test "reconciliation skips a targetable skill-unit cell sharing the footprint" do
    Mimic.copy(Catalog)
    stub(Catalog, :ground_module_for, fn :combat_only_field -> {:ok, CombatOnlyField} end)

    stub(Interpreter, :apply_status, fn unit_type, unit_id, status_type, params ->
      StatusStorage.apply_status(unit_type, unit_id, status_type, params)
      :ok
    end)

    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    allow(Catalog, self(), manager)
    allow(Interpreter, self(), manager)

    :ok = SpatialIndex.add_unit(:player, 11, 5, 5, "prontera")

    :ok =
      SpatialIndex.add_skill_unit(%Cell{
        cell_id: 500,
        group_id: 0,
        map_name: "prontera",
        x: 5,
        y: 5
      })

    group = %Group{
      group_id: 101,
      skill_id: 999,
      skill_name: :combat_only_field,
      level: 1,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: {5, 5},
      cells: [{5, 5}],
      next_tick_at: 1_000,
      expires_at: System.monotonic_time(:millisecond) + 100_000,
      interval: 1_000
    }

    assert :ok = Manager.register(manager, group)
    assert Process.alive?(manager)
    assert FieldSupport.supported?(:player, 11, :sc_quagmire)
    refute FieldSupport.supported?(:skill_unit, 500, :sc_quagmire)
  end

  test "movement reconciliation updates cached field occupants while acquiring and releasing support" do
    Mimic.copy(Catalog)
    stub(Catalog, :ground_module_for, fn :stationary_field -> {:ok, StationaryField} end)

    stub(Interpreter, :apply_status, fn unit_type, unit_id, status_type, params ->
      StatusStorage.apply_status(unit_type, unit_id, status_type, params)
      :ok
    end)

    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    allow(Catalog, self(), manager)
    allow(Interpreter, self(), manager)

    :ok = SpatialIndex.add_unit(:player, 11, 8, 8, "prontera")

    group = %Group{
      group_id: 100,
      skill_id: 999,
      skill_name: :stationary_field,
      level: 2,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: {5, 5},
      cells: [{5, 5}],
      next_tick_at: 1_000,
      expires_at: System.monotonic_time(:millisecond) + 100_000,
      interval: 1_000
    }

    assert :ok = Manager.register(manager, group)
    refute FieldSupport.supported?(:player, 11, :sc_quagmire)

    assert :ok = SpatialIndex.remove_unit(:player, 11)
    assert :ok = SpatialIndex.add_unit(:player, 11, 5, 5, "prontera")
    assert :ok = Manager.reconcile_unit(manager, {:player, 11})
    assert FieldSupport.supported?(:player, 11, :sc_quagmire)
    assert Storage.get(100).state.field_support_occupants == MapSet.new([{:player, 11}])

    assert :ok = SpatialIndex.remove_unit(:player, 11)
    assert :ok = SpatialIndex.add_unit(:player, 11, 8, 8, "prontera")
    assert :ok = Manager.reconcile_unit(manager, {:player, 11})
    refute FieldSupport.supported?(:player, 11, :sc_quagmire)
    assert Storage.get(100).state.field_support_occupants == MapSet.new()
  end
end

defmodule Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupportRealInterpreterTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule Entity do
    def get_entity_info(_state), do: %{stats: %{}}
  end

  setup :setup_ets_tables

  test "real status materialization stays alive through overlap and removes after the last source" do
    :ok = UnitRegistry.register_unit(:player, 77, Entity, %{})

    first = [level: 1, val1: 1, val2: 5]
    second = [level: 5, val1: 5, val2: 25]

    assert :ok = FieldSupport.acquire(:player, 77, :sc_quagmire, 70, first)
    assert :ok = FieldSupport.acquire(:player, 77, :sc_quagmire, 70, first)

    assert %{val1: 1, val2: 5, expires_at: nil} =
             StatusStorage.get_status(:player, 77, :sc_quagmire)

    assert :ok = FieldSupport.acquire(:player, 77, :sc_quagmire, 71, second)

    assert %{val1: 5, val2: 25, expires_at: nil} =
             StatusStorage.get_status(:player, 77, :sc_quagmire)

    assert :ok = FieldSupport.release(:player, 77, :sc_quagmire, 70)
    assert StatusStorage.has_status?(:player, 77, :sc_quagmire)
    assert :ok = FieldSupport.release(:player, 77, :sc_quagmire, 71)
    refute StatusStorage.has_status?(:player, 77, :sc_quagmire)

    assert Interpreter.can_move?(:player, 77)
  end

  test "manager reconciliation releases Quagmire support after leaving for an empty cell" do
    :ok = UnitRegistry.register_unit(:player, 77, Entity, %{})
    :ok = SpatialIndex.add_unit(:player, 77, 20, 20, "prontera")
    assert :ok = FieldSupport.acquire(:player, 77, :sc_quagmire, 70, level: 1, val2: 5)
    assert StatusStorage.has_status?(:player, 77, :sc_quagmire)

    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    assert :ok = Manager.reconcile_unit(manager, {:player, 77})
    assert FieldSupport.sources_for_unit(:player, 77) == []
    refute StatusStorage.has_status?(:player, 77, :sc_quagmire)
  end
end
