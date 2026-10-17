defmodule Aesir.ZoneServer.Unit.Mob.MobAttackedThinkTest do
  @moduledoc """
  Verifies the think an attacked event runs in the mob's own session: it sees
  the skill state the mob had before the hit, it keeps a dormant mob acting,
  the rude-attack count resets when a periodic `rudeattacked` row is picked
  even if its cast is refused, and the event think and a tick within one
  attack delay attack once.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  # A private seeded status table keeps another async test's status on the
  # same mob instance id from leaking into this file.
  setup :setup_ets_tables

  @first {:player, 42}
  @second {:player, 43}

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(StatusStorage, :has_status?, fn _unit_type, _unit_id, _status -> false end)
    stub(StatusInterpreter, :concealed?, fn _unit_type, _unit_id -> false end)
    stub(StatusInterpreter, :targetable?, fn :player, _id -> true end)
    stub(StatusInterpreter, :can_attack?, fn :mob, 1 -> true end)

    stub(UnitRegistry, :get_unit, fn
      :player, _id ->
        {:ok, {nil, %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 100}}}, nil}}

      _type, _id ->
        {:error, :not_found}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 42 -> {:ok, {101, 100, "prontera"}}
      :player, 43 -> {:ok, {100, 101, "prontera"}}
      _type, _id -> {:error, :not_found}
    end)

    :ok
  end

  describe "an aggressive mob in combat hit by a second attacker" do
    test "uses its angry skills in the think of the event" do
      row = angry_row()
      stub(MobSkillDb, :rows_for, fn 1001 -> [row] end)
      stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)

      {:noreply, updated} = attacked(aggressive_mob(), @second)

      assert %{row: ^row} = updated.casting
      assert updated.target_ref == @first
      assert updated.attacked_ref == @second
      assert_receive {:casting, :complete}, 500
    end

    test "switches to it and attacks it, leaving its angry state" do
      stub(MobSkillDb, :rows_for, fn 1001 -> [] end)
      expect(Combat, :execute_mob_attack, fn _state, @second -> :ok end)

      {:noreply, updated} = attacked(aggressive_mob(), @second)

      assert updated.target_ref == @second
      assert MobState.skill_state(updated) == :berserk
    end
  end

  test "an event on a dormant mob wakes its AI loop" do
    stub(MobSkillDb, :rows_for, fn 1001 -> [] end)
    stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)
    dormant = %{mob_state() | ai_awake: false, ai_timer_ref: nil}

    {:noreply, updated} = attacked(dormant, @first)

    assert updated.ai_awake
    assert is_reference(updated.ai_timer_ref)
    assert updated.target_ref == @first
  end

  test "a periodic rudeattacked pick resets the rude-attack count even when its cast is refused" do
    stub(MobSkillDb, :rows_for, fn 1001 ->
      [%{angry_row() | state: :attack, condition: %{type: :rudeattacked}}]
    end)

    stub(StatusInterpreter, :can_use_skill?, fn :mob, 1, 19 -> false end)
    stub(Combat, :execute_mob_attack, fn _state, _target -> :ok end)
    state = %{mob_state() | skill_state: :berserk, target_ref: @first, attacked_count: 1}

    {:noreply, updated} = MobSession.handle_cast({:ai, {:hard, 42}}, state)

    assert updated.casting == nil
    assert updated.attacked_count == 0
  end

  test "the event think and a tick within one attack delay attack once" do
    stub(MobSkillDb, :rows_for, fn 1001 -> [] end)
    expect(Combat, :execute_mob_attack, 1, fn _state, @first -> :ok end)
    state = %{mob_state() | skill_state: :berserk, target_ref: @first}

    {:noreply, after_event} = attacked(state, @first)
    {:noreply, resting} = MobSession.handle_cast({:ai, {:hard, 42}}, after_event)

    {:noreply, _rested} =
      MobSession.handle_cast({:ai, {:hard, 42}}, %{resting | next_think_at: nil})

    assert is_integer(after_event.last_attack_time)
  end

  defp attacked(state, attacker),
    do: MobSession.handle_info({:ai, {:attacked, attacker, false}}, state)

  defp aggressive_mob do
    %{mob_state() | skill_state: :angry, aggressive: true, target_ref: @first}
  end

  defp angry_row do
    %{
      skill: "MG_FIREBOLT",
      skill_id: 19,
      state: :angry,
      level: 3,
      rate: 10_000,
      cast_time: 50,
      delay: 5_000,
      cancelable: false,
      target: :target,
      condition: %{type: :always},
      emotion: nil
    }
  end

  defp mob_state do
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
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      modes: [:can_move, :can_attack]
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    %{MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100) | spawn_tick_pending?: false}
  end
end
