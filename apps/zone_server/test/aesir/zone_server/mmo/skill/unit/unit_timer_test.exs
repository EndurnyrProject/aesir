defmodule Aesir.ZoneServer.Mmo.Skill.Unit.UnitTimerTest.Strike do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_interval(%Group{} = group, _now), do: {:ok, group}

  def unit_targets(%Group{state: %{refuse: refused}}, _cell, refs), do: refs -- refused
  def unit_targets(%Group{}, _cell, refs), do: refs

  def on_unit_hit(%Group{state: %{test_pid: test_pid}} = group, cell, ref, now) do
    send(test_pid, {:struck, group.group_id, cell, ref, now})
    strike_result(group)
  end

  defp strike_result(%Group{state: %{commands: commands}} = group),
    do: {:ok, group, commands}

  defp strike_result(%Group{state: %{replace_unit: true} = state} = group) do
    generation = Map.get(state, :unit_generation, 0)

    {:ok,
     %{group | state: %{state | replace_unit: false} |> Map.put(:unit_generation, generation + 1)}}
  end

  defp strike_result(%Group{} = group), do: {:ok, group}
end

defmodule Aesir.ZoneServer.Mmo.Skill.Unit.UnitTimerTest.Phase do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_interval(%Group{} = group, _now), do: {:ok, group}
  def unit_targets(%Group{}, _cell, refs), do: refs

  def on_unit_hit(%Group{state: %{test_pid: test_pid, trap: trap}} = group, _cell, ref, _now) do
    send(test_pid, {:struck_in_phase, group.group_id, ref, trap.phase})
    {:ok, group}
  end
end

defmodule Aesir.ZoneServer.Mmo.Skill.Unit.UnitTimerTest.Burnout do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_interval(%Group{} = group, _now), do: {:ok, group}
  def unit_targets(%Group{}, _cell, refs), do: refs

  def on_unit_hit(%Group{state: %{test_pid: test_pid} = state} = group, cell, ref, _now) do
    send(test_pid, {:burned, cell, ref})
    group = %{group | state: Map.update!(state, :strikes, &(&1 + 1))}

    removal = {:remove_cells, group.group_id, Map.get(state, :remove, [cell])}
    removal = if Map.get(state, :after_cell, false), do: {:after_cell, removal}, else: removal
    {Map.get(state, :tag, :ok), group, [removal]}
  end

  def on_expire(%Group{state: %{test_pid: test_pid}} = group) do
    send(test_pid, {:ended, group.group_id})
    :ok
  end
end

defmodule Aesir.ZoneServer.Mmo.Skill.Unit.UnitTimerTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skill.Unit.UnitTimer
  alias Aesir.ZoneServer.Unit.SpatialIndex

  alias __MODULE__.Burnout
  alias __MODULE__.Phase
  alias __MODULE__.Strike

  setup :setup_ets_tables

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    %{manager: manager}
  end

  @map "prontera"

  defp field(group_id, cells, attrs \\ []) do
    struct(
      %Group{
        group_id: group_id,
        skill_id: 89,
        skill_name: :test_field,
        level: 1,
        caster_id: 1,
        caster_type: :player,
        map_name: @map,
        center: hd(cells),
        cells: cells,
        created_at: 0,
        next_tick_at: nil,
        expires_at: 10_000,
        interval: 450,
        unit_range: 1,
        handler: Strike,
        state: %{test_pid: self()}
      },
      attrs
    )
  end

  defp mob_at(id, x, y), do: SpatialIndex.add_unit(:mob, id, x, y, @map)

  test "a field reaches its cells dilated by the unit range", %{manager: manager} do
    :ok = Manager.register(manager, field(1, [{50, 50}]))
    mob_at(1, 51, 51)
    mob_at(2, 52, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:struck, 1, {50, 50}, {:mob, 1}, 1_000}
    refute_received {:struck, _, _, {:mob, 2}, _}
  end

  test "each target is struck once per interval, a newcomer on the next tick", %{
    manager: manager
  } do
    :ok = Manager.register(manager, field(1, [{50, 50}, {51, 50}]))
    mob_at(1, 50, 50)

    :ok = Manager.tick(manager, 1_000)
    assert_received {:struck, 1, _cell, {:mob, 1}, 1_000}
    refute_received {:struck, _, _, {:mob, 1}, _}

    mob_at(2, 51, 50)
    :ok = Manager.tick(manager, 1_100)
    assert_received {:struck, 1, _cell, {:mob, 2}, 1_100}

    :ok = Manager.tick(manager, 1_400)
    refute_received {:struck, _, _, _, _}

    :ok = Manager.tick(manager, 1_500)
    assert_received {:struck, 1, _cell, {:mob, 1}, 1_500}
    refute_received {:struck, _, _, {:mob, 2}, _}
  end

  test "overlapping NoOverlap groups of one skill strike a target once between them", %{
    manager: manager
  } do
    :ok = Manager.register(manager, field(1, [{50, 50}], no_overlap: true))
    :ok = Manager.register(manager, field(2, [{50, 50}], no_overlap: true))
    mob_at(1, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:struck, _group, _cell, {:mob, 1}, 1_000}
    refute_received {:struck, _, _, {:mob, 1}, _}
  end

  test "a refused target does not spend the shared NoOverlap interval", %{manager: manager} do
    refusing =
      field(1, [{50, 50}], no_overlap: true, state: %{test_pid: self(), refuse: [{:mob, 1}]})

    :ok = Manager.register(manager, refusing)
    :ok = Manager.register(manager, field(2, [{50, 50}], no_overlap: true))
    mob_at(1, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:struck, 2, _cell, {:mob, 1}, 1_000}
  end

  test "groups without NoOverlap each strike the target", %{manager: manager} do
    :ok = Manager.register(manager, field(1, [{50, 50}]))
    :ok = Manager.register(manager, field(2, [{50, 50}]))
    mob_at(1, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:struck, 1, _cell, {:mob, 1}, 1_000}
    assert_received {:struck, 2, _cell, {:mob, 1}, 1_000}
  end

  test "a cell under Land Protector strikes nothing", %{manager: manager} do
    :ok = Manager.register(manager, field(1, [{50, 50}, {53, 50}]))

    :ok =
      Storage.insert(%Group{
        group_id: 9,
        skill_name: :sa_landprotector,
        map_name: @map,
        center: {50, 50},
        cells: [{50, 50}],
        state: %{land_protector: true}
      })

    mob_at(1, 50, 50)
    mob_at(2, 53, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:struck, 1, {53, 50}, {:mob, 2}, 1_000}
    refute_received {:struck, _, _, {:mob, 1}, _}
  end

  test "an expired field strikes nothing", %{manager: manager} do
    :ok = Manager.register(manager, field(1, [{50, 50}], expires_at: 1_000))
    mob_at(1, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    refute_received {:struck, _, _, _, _}
  end

  test "a strike's command runs at once and the group it changes acts changed for the rest of the pass",
       %{manager: manager} do
    spender =
      field(1, [{50, 50}],
        state: %{test_pid: self(), commands: [{:spend_traps, @map, {50, 50}, 2}]}
      )

    {:ok, armed} = TrapState.new(%{claymore_spendable?: true})
    trap = field(2, [{51, 50}], handler: Phase, state: %{test_pid: self(), trap: armed})

    :ok = Manager.register(manager, spender)
    :ok = Manager.register(manager, trap)
    mob_at(1, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:struck, 1, {50, 50}, {:mob, 1}, 1_000}
    assert_received {:struck_in_phase, 2, {:mob, 1}, :used}
    assert %Group{state: %{trap: %TrapState{phase: :used}}} = Storage.get(2)
  end

  test "a unit_generation bump stops the cell's remaining strikes and the new unit starts fresh",
       %{manager: manager} do
    :ok =
      Manager.register(
        manager,
        field(1, [{50, 50}], state: %{test_pid: self(), replace_unit: true})
      )

    mob_at(1, 50, 50)
    mob_at(2, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:struck, 1, {50, 50}, _first, 1_000}
    refute_received {:struck, _, _, _, _}
    assert %Group{state: %{unit_generation: 1}} = Storage.get(1)

    :ok = Manager.tick(manager, 1_100)

    assert_received {:struck, 1, {50, 50}, {:mob, 1}, 1_100}
    assert_received {:struck, 1, {50, 50}, {:mob, 2}, 1_100}
  end

  test "a strike removing its own cell ends that cell at once and the group keeps its pass state",
       %{manager: manager} do
    burnout = field(1, [{50, 50}, {53, 50}], unit_range: 0, handler: Burnout)
    :ok = Manager.register(manager, %{burnout | state: %{test_pid: self(), strikes: 0}})
    mob_at(1, 50, 50)
    mob_at(2, 50, 50)
    mob_at(3, 53, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:burned, {50, 50}, _first}
    refute_received {:burned, {50, 50}, _second}
    assert_received {:burned, {53, 50}, {:mob, 3}}
    assert Storage.get_cells_by_group(1) == []
    assert Storage.get(1) == nil
  end

  test "a group losing some cells keeps the rest with its pass state", %{manager: manager} do
    burnout = field(1, [{50, 50}, {53, 50}], unit_range: 0, handler: Burnout)
    :ok = Manager.register(manager, %{burnout | state: %{test_pid: self(), strikes: 0}})
    mob_at(1, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:burned, {50, 50}, {:mob, 1}}
    assert %Group{cells: [{53, 50}], state: %{strikes: 1}} = Storage.get(1)
    assert [%Cell{x: 53, y: 50}] = Storage.get_cells_by_group(1)
  end

  test "an expiring strike removing the last cell strikes nobody else and ends the group once",
       %{manager: manager} do
    burnout = field(1, [{50, 50}], unit_range: 0, handler: Burnout)

    :ok =
      Manager.register(manager, %{burnout | state: %{test_pid: self(), strikes: 0, tag: :expire}})

    mob_at(1, 50, 50)
    mob_at(2, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:burned, {50, 50}, _first}
    refute_received {:burned, {50, 50}, _second}
    assert_received {:ended, 1}
    refute_received {:ended, 1}
    assert Storage.get(1) == nil
  end

  test "a removal deferred to the end of the cell strikes every unit on it first",
       %{manager: manager} do
    burnout = field(1, [{50, 50}, {53, 50}], unit_range: 0, handler: Burnout)

    :ok =
      Manager.register(manager, %{
        burnout
        | state: %{test_pid: self(), strikes: 0, after_cell: true}
      })

    mob_at(1, 50, 50)
    mob_at(2, 50, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:burned, {50, 50}, {:mob, 1}}
    assert_received {:burned, {50, 50}, {:mob, 2}}
    assert %Group{cells: [{53, 50}], state: %{strikes: 2}} = Storage.get(1)
  end

  test "a cell removed earlier in the pass strikes nothing", %{manager: manager} do
    burnout = field(1, [{50, 50}, {53, 50}, {56, 50}], unit_range: 0, handler: Burnout)

    :ok =
      Manager.register(manager, %{
        burnout
        | state: %{test_pid: self(), strikes: 0, remove: [{53, 50}]}
      })

    mob_at(1, 50, 50)
    mob_at(2, 53, 50)

    :ok = Manager.tick(manager, 1_000)

    assert_received {:burned, {50, 50}, {:mob, 1}}
    refute_received {:burned, {53, 50}, _}
    assert %Group{cells: [{50, 50}, {56, 50}]} = Storage.get(1)
  end

  test "cells run in skill-unit table order: id remainder by 283, then id" do
    wrap = 283 * 5_216_944 + 282

    cells =
      for {id, x} <- [{wrap, 1}, {wrap + 1, 2}, {wrap + 284, 3}] do
        %Cell{cell_id: id, group_id: 1, map_name: @map, x: x, y: 0}
      end

    assert [2, 3, 1] = cells |> UnitTimer.order() |> Enum.map(& &1.x)
  end
end
