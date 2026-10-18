defmodule Aesir.ZoneServer.Unit.Mob.ChaseWalkTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 200, 200)})
    :ok
  end

  test "random-target attack orders pick a visible living enemy, not the AI's dead target" do
    state = chasing_mob()

    state = %{
      state
      | mob_data: %{state.mob_data | modes: [:can_attack, :can_move, :random_target]}
    }

    dead = PlayerState.new(%Character{id: 17, hp: 0})
    living = PlayerState.new(%Character{id: 18, hp: 100})
    UnitRegistry.register_unit(:player, 17, PlayerState, dead, self())
    UnitRegistry.register_unit(:player, 18, PlayerState, living, self())
    SpatialIndex.add_unit(:player, 17, 101, 100, "prontera")
    SpatialIndex.add_unit(:player, 18, 100, 101, "prontera")
    parent = self()

    stub(Combat, :execute_mob_attack, fn _, target ->
      send(parent, {:attack, target})
      :ok
    end)

    result = AIStateMachine.attack_once(state, {:player, 17})

    assert_received {:attack, {:player, 18}}
    assert result.attack_target == {:player, 18}
    assert result.target_ref == {:player, 17}

    SpatialIndex.update_unit_position(:player, 18, 103, 100, "prontera")
    Mimic.copy(LineOfSight)
    stub(LineOfSight, :clear?, fn _, _, _ -> false end)
    state = %{state | mob_data: %{state.mob_data | attack_range: 4}}
    blocked = AIStateMachine.attack_once(state, {:player, 17})
    assert blocked.attack_target == nil
    refute_received {:attack, _}
  end

  test "Ice Wall failed steps contribute to a rude attack when a status prevents movement" do
    state = chasing_mob()
    state = %{state | attacked_ref: {:player, 17}, attacked_count: 1, walk_fail_count: 1}
    player = PlayerState.new(%Character{id: 17, hp: 100})
    UnitRegistry.register_unit(:player, 17, PlayerState, player, self())
    SpatialIndex.add_unit(:player, 17, 104, 100, "prontera")
    stub(Interpreter, :can_move?, fn :mob, 919 -> false end)

    {result, rude?} = AIStateMachine.process_attacked(state)

    assert rude?
    assert result.attacked_count == 2
    assert result.attacked_ref == nil
  end

  test "a refused attack keeps walking, while a vanished target unlocks without repathing" do
    state = chasing_mob()
    player = PlayerState.new(%Character{id: 17, hp: 100})
    UnitRegistry.register_unit(:player, 17, PlayerState, player, self())
    SpatialIndex.add_unit(:player, 17, 102, 100, "prontera")
    stub(Interpreter, :charmed_against?, fn :mob, 919, 17 -> true end)
    {:noreply, moving} = MovementHandler.handle_move_to(state, 109, 100, chase: true)

    {:noreply, refused} = MovementHandler.handle_movement_tick(moving)

    assert refused.movement_state == :moving
    assert refused.attack_target == nil
    assert List.last(refused.walk_path) == {109, 100}
    SpatialIndex.remove_unit(:player, 17)
    UnitRegistry.unregister_unit(:player, 17)

    {:noreply, lost} = MovementHandler.handle_movement_tick(refused)

    assert lost.target_ref == nil
    assert lost.movement_state == :moving
    assert List.last(lost.walk_path) == {109, 100}
    HitStop.cancel(lost.pending_step)
  end

  test "a failed penultimate-cell repath preserves the remaining walk but releases its chase order" do
    state = chasing_mob()
    player = PlayerState.new(%Character{id: 17, hp: 100})
    UnitRegistry.register_unit(:player, 17, PlayerState, player, self())
    SpatialIndex.add_unit(:player, 17, 110, 100, "prontera")
    {:noreply, moving} = MovementHandler.handle_move_to(state, 102, 100, chase: true)

    map =
      Enum.reduce(0..199, MapData.new("prontera", 200, 200), fn y, map ->
        MapData.set_cell(map, 105, y, 1)
      end)

    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map})

    {:noreply, continued} = MovementHandler.handle_movement_tick(moving)

    assert continued.movement_state == :moving
    assert continued.walk_path == [{102, 100}]
    assert continued.target_ref == {:player, 17}
    assert continued.chase_target == nil
    HitStop.cancel(continued.pending_step)
  end

  test "a dead chase target is dropped before a status can refuse the attack" do
    state = chasing_mob()
    dead = PlayerState.new(%Character{id: 17, hp: 0})
    UnitRegistry.register_unit(:player, 17, PlayerState, dead, self())
    SpatialIndex.add_unit(:player, 17, 101, 100, "prontera")
    stub(Interpreter, :can_attack?, fn :mob, 919 -> false end)

    assert {:stop, stopped} = AIStateMachine.walk_chase(state, true, false)
    assert stopped.target_ref == nil
  end

  test "the penultimate cell redirects a chase toward the target's new position" do
    state = chasing_mob()
    player = PlayerState.new(%Character{id: 17, last_map: "prontera", last_x: 110, last_y: 100})
    UnitRegistry.register_unit(:player, 17, PlayerState, player, self())
    SpatialIndex.add_unit(:player, 17, 110, 100, "prontera")
    {:noreply, moving} = MovementHandler.handle_move_to(state, 102, 100, chase: true)
    SpatialIndex.update_unit_position(:player, 17, 110, 102, "prontera")

    {:noreply, redirected} = MovementHandler.handle_movement_tick(moving)

    assert List.last(redirected.walk_path) == {109, 101}
    assert redirected.movement_state == :moving
    HitStop.cancel(redirected.pending_step)
  end

  defp chasing_mob do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}
    state = MobState.new(919, data, spawn, "prontera", 100, 100)

    %{
      state
      | target_ref: {:player, 17},
        chase_target: {:player, 17},
        last_skillcheck: System.system_time(:millisecond)
    }
  end

  test "a chase attacks on the first completed cell that brings its target into range" do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}
    state = MobState.new(919, data, spawn, "prontera", 100, 100)

    state = %{
      state
      | target_ref: {:player, 17},
        chase_target: {:player, 17},
        last_skillcheck: System.system_time(:millisecond)
    }

    player = PlayerState.new(%Character{id: 17, last_map: "prontera", last_x: 110, last_y: 100})
    UnitRegistry.register_unit(:player, 17, PlayerState, player, self())
    SpatialIndex.add_unit(:player, 17, 110, 100, "prontera")
    parent = self()

    stub(Combat, :execute_mob_attack, fn mob, target ->
      send(parent, {:attack, mob.x, mob.y, target})
      :ok
    end)

    {:noreply, moving} = MovementHandler.handle_move_to(state, 109, 100, chase: true)
    refute_received {:attack, _, _, _}
    SpatialIndex.update_unit_position(:player, 17, 102, 100, "prontera")

    {:noreply, stopped} = MovementHandler.handle_movement_tick(moving)

    assert_received {:attack, 101, 100, {:player, 17}}
    assert stopped.movement_state == :standing
    assert stopped.attack_target == {:player, 17}
    assert stopped.skill_state == :berserk
    HitStop.cancel(stopped.pending_step)
  end
end
