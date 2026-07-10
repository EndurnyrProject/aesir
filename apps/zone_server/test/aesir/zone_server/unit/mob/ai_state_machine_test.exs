defmodule Aesir.ZoneServer.Unit.Mob.AIStateMachineTest do
  @moduledoc """
  Verifies mob self-gating: a mob carrying a `no_move` / `no_attack` status does
  not issue movement or attack on its AI tick (design §4 mob self-gating rows).
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(Interpreter)
    Mimic.copy(MobSession)
    Mimic.copy(Combat)
    Mimic.copy(SpatialIndex)
    Mimic.copy(MapCache)
    Mimic.copy(MapData)

    stub(Interpreter, :can_move?, fn _type, _id -> true end)
    stub(Interpreter, :can_attack?, fn _type, _id -> true end)
    stub(Interpreter, :targetable?, fn _type, _id -> true end)
    stub(MapCache, :get, fn _map -> {:ok, :map_data} end)
    stub(MapData, :walkable?, fn _map_data, _x, _y -> true end)
    stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _range -> [] end)
    :ok
  end

  describe "move_toward/3 status gating" do
    test "a no_move mob does not issue movement and its state is unchanged" do
      test_pid = self()
      stub(MobSession, :move_to, fn _pid, _x, _y -> send(test_pid, :moved) end)
      stub(Interpreter, :can_move?, fn :mob, 1 -> false end)

      state = movable_mob_state()

      assert AIStateMachine.move_toward(state, 105, 105) == state
      refute_received :moved
    end

    test "an unafflicted mob issues movement as before" do
      test_pid = self()
      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      state = movable_mob_state()

      assert AIStateMachine.move_toward(state, 105, 105) == state
      assert_received {:moved, 105, 105}
    end
  end

  describe "execute_mob_attack via process_ai status gating" do
    test "a no_attack mob does not attack and last_attack_time is unchanged" do
      test_pid = self()
      stub(Interpreter, :can_attack?, fn :mob, 1 -> false end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target ->
        send(test_pid, :attacked)
        :ok
      end)

      state = combat_mob_state()

      result = AIStateMachine.process_ai(state)

      refute_received :attacked
      assert result.last_attack_time == state.last_attack_time
    end

    test "an unafflicted mob attacks and updates last_attack_time" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target ->
        send(test_pid, :attacked)
        :ok
      end)

      state = combat_mob_state()

      result = AIStateMachine.process_ai(state)

      assert_received :attacked
      assert result.last_attack_time != nil
    end
  end

  describe "find_nearby_targets/1 targeting filter via process_ai aggro" do
    test "an untargetable (trick-dead) player is not acquired by an idle aggressive mob" do
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)

      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      state = aggressive_idle_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_id == nil
      assert result.ai_state == :idle
    end

    test "a targetable player is acquired by an idle aggressive mob" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      state = aggressive_idle_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_id == 2
      assert result.ai_state == :alert
    end

    test "aggro acquired by scan marks the combat as self-initiated" do
      stub(SpatialIndex, :get_units_in_range, fn :player, "prontera", 100, 100, _range ->
        [2]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {101, 101, "prontera"}}
      end)

      state = aggressive_idle_mob_state()

      result = AIStateMachine.check_aggro(state)

      assert result.target_id == 2
      assert result.ai_state == :alert
      assert result.initiated_by_self? == true
    end
  end

  describe "handle_damage_reaction/2 initiator tagging" do
    test "an idle mob attacked by a specific entity retaliates (not self-initiated)" do
      state = %MobState{base_mob_state() | ai_state: :idle, initiated_by_self?: true}

      result = AIStateMachine.handle_damage_reaction(state, 2)

      assert result.target_id == 2
      assert result.ai_state == :combat
      assert result.initiated_by_self? == false
    end

    test "switching to a higher-aggro attacker clears the self-initiated flag" do
      state =
        %MobState{
          base_mob_state()
          | ai_state: :alert,
            target_id: 2,
            initiated_by_self?: true
        }
        |> MobState.add_aggro(3, 100)

      result = AIStateMachine.handle_damage_reaction(state, 3)

      assert result.target_id == 3
      assert result.initiated_by_self? == false
    end
  end

  describe "process_combat/1 sheds aggro on untargetable target" do
    test "a mob in combat drops a target that became untargetable (return to idle)" do
      test_pid = self()
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target ->
        send(test_pid, :attacked)
        :ok
      end)

      state = combat_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_id == nil
      assert result.ai_state == :idle
      refute_received :attacked
    end

    test "a mob in combat retains a still-targetable target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)

      state = combat_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_id == 2
    end
  end

  describe "process_chase/1 sheds aggro on untargetable target" do
    test "a mob in chase drops a target that became untargetable (return to spawn)" do
      stub(Interpreter, :targetable?, fn :player, 2 -> false end)

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(MobSession, :move_to, fn _pid, _x, _y -> :ok end)

      state = chase_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_id == nil
      assert result.ai_state == :return
    end

    test "a mob in chase retains a still-targetable target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(MobSession, :move_to, fn _pid, _x, _y -> :ok end)

      state = chase_mob_state()

      result = AIStateMachine.process_ai(state)

      assert result.target_id == 2
      assert result.ai_state in [:chase, :combat, :alert]
    end
  end

  describe "process_chase/1 targets an adjacent, unoccupied cell" do
    test "a chasing mob paths to a cell adjacent to the player, never the player's cell" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, 2 ->
        {:ok, {105, 105, "prontera"}}
      end)

      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      AIStateMachine.process_ai(chase_mob_state())

      assert_received {:moved, dest_x, dest_y}
      assert {dest_x, dest_y} != {105, 105}
      assert Geometry.chebyshev_distance(dest_x, dest_y, 105, 105) <= 2
    end

    test "re-picks another adjacent cell when the best cell is occupied" do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn
        :player, 2 -> {:ok, {105, 105, "prontera"}}
        :mob, 55 -> {:ok, {103, 103, "prontera"}}
      end)

      # (103,103) is the closest walkable adjacent cell along the approach; a
      # second unit sitting there must be avoided rather than overlapped.
      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, _range ->
        [{:mob, 55}]
      end)

      stub(MobSession, :move_to, fn _pid, x, y -> send(test_pid, {:moved, x, y}) end)

      AIStateMachine.process_ai(chase_mob_state())

      assert_received {:moved, dest_x, dest_y}
      assert {dest_x, dest_y} != {103, 103}
      assert {dest_x, dest_y} != {105, 105}
      assert Geometry.chebyshev_distance(dest_x, dest_y, 105, 105) <= 2
    end
  end

  describe "spawn anchoring" do
    test "spawn checks anchor on the cell the mob spawned at, not the raw spawn config" do
      # Imported rAthena spawn lines use x/y 0,0 ("random cell anywhere"); the
      # AI must anchor on the resolved spawn_point or every mob would try to
      # wander to and return toward the map corner.
      state = %MobState{
        base_mob_state()
        | spawn_ref: %MobSpawn{
            mob: 1001,
            amount: 1,
            respawn_time: 5000,
            spawn_area: %SpawnArea{x: 0, y: 0}
          }
      }

      assert AIStateMachine.at_spawn_area?(state)
      refute AIStateMachine.should_return_to_spawn?(state)
    end

    test "a mob far from its spawn point wants to return to it" do
      state = %MobState{base_mob_state() | x: 200, y: 200}

      refute AIStateMachine.at_spawn_area?(state)
      assert AIStateMachine.should_return_to_spawn?(state)
    end
  end

  defp aggressive_idle_mob_state do
    base = base_mob_state(modes: [:aggressive])

    %MobState{base | x: 100, y: 100, ai_state: :idle, target_id: nil}
  end

  defp chase_mob_state do
    %MobState{
      base_mob_state()
      | x: 100,
        y: 100,
        ai_state: :chase,
        target_id: 2,
        movement_state: :standing,
        process_pid: self()
    }
  end

  defp movable_mob_state do
    %MobState{
      base_mob_state()
      | process_pid: self(),
        x: 100,
        y: 100,
        movement_state: :standing,
        last_movement_end_time: nil
    }
  end

  defp combat_mob_state do
    %MobState{
      base_mob_state()
      | x: 100,
        y: 100,
        ai_state: :combat,
        target_id: 2,
        last_attack_time: nil
    }
  end

  defp base_mob_state(opts \\ []) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 2,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      modes: Keyword.get(opts, :modes, [])
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
