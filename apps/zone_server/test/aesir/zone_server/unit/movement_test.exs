defmodule Aesir.ZoneServer.Unit.MovementTest.TouchSpy do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  def on_touch(%Group{group_id: gid, state: %{test_pid: test_pid}}, mover) do
    send(test_pid, {:touched, gid, mover})
    :expire
  end

  def on_expire(%Group{group_id: gid, state: %{test_pid: test_pid}}) do
    send(test_pid, {:expired, gid})
    :ok
  end
end

defmodule Aesir.ZoneServer.Unit.MovementTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  alias __MODULE__.TouchSpy

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(StatusInterpreter)

    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    allow(Catalog, self(), manager)
    :ok
  end

  defp touch_group(group_id, map_name) do
    %Group{
      group_id: group_id,
      skill_id: 999,
      skill_name: :test_trap,
      level: 1,
      caster_id: 2000,
      caster_type: :player,
      map_name: map_name,
      center: {55, 60},
      cells: [{55, 60}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: %{test_pid: self()}
    }
  end

  describe "set_position/4" do
    test "commits a prevalidated forced-movement destination through the choke point" do
      char_id = 1003
      map_name = "prontera"
      directive = %ForcedMovement{map_name: map_name, x: 55, y: 60}

      UnitRegistry.register_unit(
        :player,
        char_id,
        __MODULE__,
        struct(PlayerState, %{movement_state: :standing}),
        nil
      )

      SpatialIndex.add_unit(:player, char_id, 50, 50, map_name)

      updated_state =
        struct(PlayerState, Map.merge(%{movement_state: :standing}, Map.from_struct(directive)))

      assert :ok = Movement.set_position(:player, char_id, updated_state, directive.map_name)

      assert {:ok, {55, 60, ^map_name}} = SpatialIndex.get_unit_position(:player, char_id)
      assert [{:player, ^char_id, 0}] = Movement.drain_dirty(map_name)
    end

    test "updates the spatial index and registry and marks the unit dirty" do
      char_id = 1001
      map_name = "prontera"

      UnitRegistry.register_unit(
        :player,
        char_id,
        __MODULE__,
        struct(PlayerState, %{movement_state: :standing}),
        nil
      )

      SpatialIndex.add_unit(:player, char_id, 50, 50, map_name)

      updated_state = struct(PlayerState, %{movement_state: :moving, x: 55, y: 60})
      assert :ok = Movement.set_position(:player, char_id, updated_state, map_name)

      assert {:ok, {55, 60, ^map_name}} = SpatialIndex.get_unit_position(:player, char_id)
      assert {:ok, {__MODULE__, ^updated_state, nil}} = UnitRegistry.get_unit(:player, char_id)
      assert [{:player, ^char_id, 1}] = Movement.drain_dirty(map_name)
    end

    test "fires ground-unit on_touch for a player mover via the single chokepoint" do
      map_name = "prontera"
      stub(Catalog, :ground_module_for, fn :test_trap -> {:ok, TouchSpy} end)

      UnitRegistry.register_unit(
        :player,
        1001,
        __MODULE__,
        struct(PlayerState, %{movement_state: :standing}),
        nil
      )

      SpatialIndex.add_unit(:player, 1001, 50, 50, map_name)
      :ok = Storage.insert(touch_group(1, map_name))

      assert :ok =
               Movement.set_position(
                 :player,
                 1001,
                 struct(PlayerState, %{movement_state: :moving, x: 55, y: 60}),
                 map_name
               )

      assert_received {:touched, 1, {:player, 1001}}
      assert nil == Storage.get(1)
    end

    test "fires ground-unit on_touch for a mob mover via the single chokepoint" do
      map_name = "prontera"
      stub(Catalog, :ground_module_for, fn :test_trap -> {:ok, TouchSpy} end)
      UnitRegistry.register_unit(:mob, 2001, __MODULE__, %{movement_state: :standing}, nil)
      SpatialIndex.add_unit(:mob, 2001, 50, 50, map_name)
      :ok = Storage.insert(touch_group(1, map_name))

      assert :ok =
               Movement.set_position(
                 :mob,
                 2001,
                 %{movement_state: :moving, x: 55, y: 60},
                 map_name
               )

      assert_received {:touched, 1, {:mob, 2001}}
      assert nil == Storage.get(1)
    end

    test "does not fire on_touch when the destination cell has no ground unit" do
      map_name = "prontera"

      UnitRegistry.register_unit(
        :player,
        1002,
        __MODULE__,
        struct(PlayerState, %{movement_state: :standing}),
        nil
      )

      SpatialIndex.add_unit(:player, 1002, 50, 50, map_name)
      :ok = Storage.insert(touch_group(1, map_name))

      assert :ok =
               Movement.set_position(
                 :player,
                 1002,
                 struct(PlayerState, %{movement_state: :moving, x: 10, y: 10}),
                 map_name
               )

      refute_received {:touched, _, _}
      assert %Group{group_id: 1} = Storage.get(1)
    end

    test "does not notify a corpse when a living mover enters contact range" do
      map_name = "prontera"
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

      UnitRegistry.register_unit(:player, 1001, __MODULE__, corpse, nil)
      SpatialIndex.add_unit(:player, 1001, 51, 50, map_name)
      UnitRegistry.register_unit(:mob, 2001, __MODULE__, %{movement_state: :standing}, nil)
      SpatialIndex.add_unit(:mob, 2001, 55, 50, map_name)

      reject(&StatusInterpreter.on_movement_contact/3)

      assert :ok =
               Movement.set_position(
                 :mob,
                 2001,
                 %{movement_state: :moving, x: 50, y: 50},
                 map_name
               )
    end

    test "does not notify an unresolved player contact" do
      map_name = "prontera"

      SpatialIndex.add_unit(:player, 1001, 51, 50, map_name)
      UnitRegistry.register_unit(:mob, 2001, __MODULE__, %{movement_state: :standing}, nil)
      SpatialIndex.add_unit(:mob, 2001, 55, 50, map_name)

      reject(&StatusInterpreter.on_movement_contact/3)

      assert :ok =
               Movement.set_position(
                 :mob,
                 2001,
                 %{movement_state: :moving, x: 50, y: 50},
                 map_name
               )
    end

    test "does not notify contacts when a corpse moves" do
      map_name = "prontera"
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

      UnitRegistry.register_unit(:player, 1001, __MODULE__, corpse, nil)
      SpatialIndex.add_unit(:player, 1001, 55, 50, map_name)
      UnitRegistry.register_unit(:mob, 2001, __MODULE__, %{movement_state: :standing}, nil)
      SpatialIndex.add_unit(:mob, 2001, 51, 50, map_name)

      reject(&StatusInterpreter.on_movement_contact/3)

      assert :ok =
               Movement.set_position(
                 :player,
                 1001,
                 %{corpse | x: 50, y: 50, movement_state: :moving},
                 map_name
               )
    end
  end

  describe "swap_positions/3" do
    test "atomically swaps both snapshots and marks both standing" do
      map_name = "amistr_swap_test"

      owner =
        struct(PlayerState, %{x: 10, y: 20, map_name: map_name, movement_state: :moving})

      homunculus = %{x: 30, y: 40, map_name: map_name, movement_state: :moving}
      swapped_owner = %{owner | x: 30, y: 40, movement_state: :standing}
      swapped_homunculus = %{homunculus | x: 10, y: 20, movement_state: :standing}

      UnitRegistry.register_unit(:player, 1001, __MODULE__, owner, self())
      UnitRegistry.register_unit(:homunculus, 2001, __MODULE__, homunculus, self())
      SpatialIndex.add_unit(:player, 1001, 10, 20, map_name)
      SpatialIndex.add_unit(:homunculus, 2001, 30, 40, map_name)

      assert :ok =
               Movement.swap_positions(
                 {:player, 1001, swapped_owner},
                 {:homunculus, 2001, swapped_homunculus},
                 map_name
               )

      assert {:ok, {30, 40, ^map_name}} = SpatialIndex.get_unit_position(:player, 1001)
      assert {:ok, {10, 20, ^map_name}} = SpatialIndex.get_unit_position(:homunculus, 2001)
      assert {:ok, {__MODULE__, ^swapped_owner, _pid}} = UnitRegistry.get_unit(:player, 1001)

      assert {:ok, {__MODULE__, ^swapped_homunculus, _pid}} =
               UnitRegistry.get_unit(:homunculus, 2001)

      assert Enum.sort(Movement.drain_dirty(map_name)) == [
               {:homunculus, 2001, 0},
               {:player, 1001, 0}
             ]
    end

    test "rejects a stale endpoint without mutating either unit" do
      map_name = "amistr_swap_stale_test"

      owner =
        struct(PlayerState, %{x: 10, y: 20, map_name: map_name, movement_state: :standing})

      homunculus = %{x: 30, y: 40, map_name: map_name, movement_state: :standing}

      UnitRegistry.register_unit(:player, 1001, __MODULE__, owner, self())
      UnitRegistry.register_unit(:homunculus, 2001, __MODULE__, homunculus, self())
      SpatialIndex.add_unit(:player, 1001, 11, 20, map_name)
      SpatialIndex.add_unit(:homunculus, 2001, 30, 40, map_name)

      assert {:error, :stale_endpoint} =
               Movement.swap_positions(
                 {:player, 1001, %{owner | x: 30, y: 40}},
                 {:homunculus, 2001, %{homunculus | x: 10, y: 20}},
                 map_name
               )

      assert {:ok, {11, 20, ^map_name}} = SpatialIndex.get_unit_position(:player, 1001)
      assert {:ok, {30, 40, ^map_name}} = SpatialIndex.get_unit_position(:homunculus, 2001)
      assert Movement.drain_dirty(map_name) == []
    end
  end

  describe "mark_dirty/4 and drain_dirty/1" do
    test "drain returns each dirty unit once and then clears them" do
      map_name = "prontera"
      Movement.mark_dirty(map_name, :player, 1, 1)
      Movement.mark_dirty(map_name, :mob, 2, 0)

      drained = Movement.drain_dirty(map_name)
      assert Enum.sort(drained) == [{:mob, 2, 0}, {:player, 1, 1}]

      assert Movement.drain_dirty(map_name) == []
    end

    test "the latest mark_dirty for a unit wins" do
      map_name = "prontera"
      Movement.mark_dirty(map_name, :player, 1, 1)
      Movement.mark_dirty(map_name, :player, 1, 0)

      assert Movement.drain_dirty(map_name) == [{:player, 1, 0}]
    end

    test "drain for one map does not return units marked on another map" do
      Movement.mark_dirty("prontera", :player, 1, 1)
      Movement.mark_dirty("geffen", :player, 2, 1)

      assert Movement.drain_dirty("prontera") == [{:player, 1, 1}]
      assert Movement.drain_dirty("geffen") == [{:player, 2, 1}]
    end
  end
end
