defmodule Aesir.ZoneServer.Unit.Mob.MobSessionSkillCastTest do
  @moduledoc """
  Verifies the mob cast phase: skill selection runs before melee on the AI
  tick, a cast_time > 0 row locks the mob in `casting` until `:cast_complete`,
  a cast_time == 0 row executes instantly, and the per-skill delay is written
  to `skill_cooldowns` whether or not the effect landed.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  @target_id 42

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    :ok
  end

  defp row(overrides \\ %{}) do
    base = %{
      skill: "NPC_FIREATTACK",
      skill_id: 186,
      state: :attack,
      level: 3,
      rate: 10_000,
      cast_time: 50,
      delay: 5_000,
      cancelable: false,
      target: :target,
      condition: %{type: :always},
      emotion: nil
    }

    Map.merge(base, Map.new(overrides))
  end

  defp build_mob_state(overrides \\ %{}) do
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
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state =
      MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
      |> MobState.set_target(@target_id)
      |> MobState.set_ai_state(:combat)

    struct(state, Map.new(overrides))
  end

  describe ":ai_tick skill selection" do
    test "a selectable cast_time > 0 row starts a cast instead of melee" do
      row = row()
      stub(MobSkillDb, :rows_for, fn 1001 -> [row] end)
      reject(&Combat.execute_mob_attack/2)
      reject(&Combat.execute_magic_damage/4)
      test_pid = self()

      expect(Broadcast, :to_in_range, fn "prontera", 100, 100, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      {:noreply, updated} = MobSession.handle_info(:ai_tick, build_mob_state())

      assert %{row: ^row, complete_at: complete_at} = updated.casting
      assert is_integer(complete_at)
      assert updated.skill_cooldowns == %{}
      assert updated.ai_timer_ref

      assert_received {:packet, %SkillCasting{src_id: 1, skill_id: 186, cast_time: 50}}
      assert_receive :cast_complete, 500
    end

    test "a cast_time == 0 row executes immediately and sets the cooldown" do
      stub(MobSkillDb, :rows_for, fn 1001 -> [row(%{cast_time: 0})] end)
      reject(&Combat.execute_mob_attack/2)

      expect(Combat, :execute_magic_damage, fn _caster, @target_id, 180, opts ->
        assert opts[:element] == :fire
        :ok
      end)

      before = System.system_time(:millisecond)
      {:noreply, updated} = MobSession.handle_info(:ai_tick, build_mob_state())

      assert updated.casting == nil
      assert updated.skill_cooldowns["NPC_FIREATTACK"] >= before + 5_000
      refute_received :cast_complete
    end

    test "a nil selection falls through to the normal melee AI" do
      stub(MobSkillDb, :rows_for, fn 1001 -> [] end)

      stub(SpatialIndex, :get_unit_position, fn :player, @target_id ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(StatusInterpreter, :targetable?, fn :player, @target_id -> true end)
      stub(StatusInterpreter, :can_attack?, fn :mob, 1 -> true end)
      test_pid = self()

      expect(Combat, :execute_mob_attack, fn _state, @target_id ->
        send(test_pid, :melee)
        :ok
      end)

      {:noreply, updated} = MobSession.handle_info(:ai_tick, build_mob_state())

      assert updated.casting == nil
      assert_received :melee
    end

    test "while casting, the tick neither melees nor re-selects" do
      state = build_mob_state() |> MobState.set_casting(%{row: row(), complete_at: 0})
      reject(&MobSkillDb.rows_for/1)
      reject(&Combat.execute_mob_attack/2)
      reject(&Combat.execute_magic_damage/4)

      {:noreply, updated} = MobSession.handle_info(:ai_tick, state)

      assert updated.casting == state.casting
      assert updated.ai_state == state.ai_state
      assert updated.ai_timer_ref
    end
  end

  describe ":cast_complete" do
    test "executes the skill, writes the cooldown, clears casting and reschedules" do
      row = row()
      state = build_mob_state() |> MobState.set_casting(%{row: row, complete_at: 0})

      expect(Combat, :execute_magic_damage, fn _caster, @target_id, 180, opts ->
        assert opts[:skill_id] == 186
        assert opts[:element] == :fire
        :ok
      end)

      before = System.system_time(:millisecond)
      {:noreply, updated} = MobSession.handle_info(:cast_complete, state)

      assert updated.casting == nil
      assert updated.skill_cooldowns["NPC_FIREATTACK"] >= before + 5_000
      assert updated.ai_timer_ref
    end

    test "an invalidated target aborts cleanly but still sets the cooldown" do
      state =
        build_mob_state()
        |> MobState.set_target(nil)
        |> MobState.set_casting(%{row: row(), complete_at: 0})

      reject(&Combat.execute_magic_damage/4)

      before = System.system_time(:millisecond)
      {:noreply, updated} = MobSession.handle_info(:cast_complete, state)

      assert updated.casting == nil
      assert updated.skill_cooldowns["NPC_FIREATTACK"] >= before + 5_000
    end

    test "a dead mob ignores cast completion" do
      state =
        build_mob_state(%{is_dead: true})
        |> MobState.set_casting(%{row: row(), complete_at: 0})

      reject(&Combat.execute_magic_damage/4)

      {:noreply, updated} = MobSession.handle_info(:cast_complete, state)

      assert updated.skill_cooldowns == %{}
    end
  end
end
