defmodule Aesir.ZoneServer.Unit.Mob.AIStateMachineTest do
  @moduledoc """
  Verifies mob self-gating: a mob carrying a `no_move` / `no_attack` status does
  not issue movement or attack on its AI tick (design §4 mob self-gating rows).
  """

  use ExUnit.Case, async: true
  use Mimic

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

    stub(Interpreter, :can_move?, fn _type, _id -> true end)
    stub(Interpreter, :can_attack?, fn _type, _id -> true end)
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

  defp base_mob_state do
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
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
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
