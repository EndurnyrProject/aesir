defmodule Aesir.ZoneServer.Unit.Mob.MobSessionSkillCastTest do
  @moduledoc """
  Verifies the mob cast phase: skill selection runs before melee on the AI
  tick, a cast_time > 0 row locks the mob in `casting` until `:cast_complete`,
  a cast_time == 0 row executes instantly, and the per-skill delay is written
  to `skill_cooldowns` whether or not the effect landed.

  Also covers aborting a cast: `interrupt_cast/1` force-cancels one and reports
  what it cancelled (losing to a completion that already drained the mailbox),
  and every abort path tears the client's cast bar down with a `CastCancel`.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.CastCancel
  alias Aesir.Net.SkillCasting
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
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  @target_id 42

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(StatusStorage, :has_status?, fn _unit_type, _unit_id, _status -> false end)
    stub(StatusInterpreter, :concealed?, fn _unit_type, _unit_id -> false end)
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

    test "a silenced mob aborts at cast_complete without executing but still sets the delay" do
      ref = Process.send_after(self(), :cast_complete, 10_000)

      state =
        build_mob_state()
        |> MobState.set_casting(%{row: row(), complete_at: 0, timer_ref: ref})

      stub(StatusStorage, :has_status?, fn
        :mob, 1, :sc_silence -> true
        :mob, _id, _status -> false
      end)

      reject(&Combat.execute_magic_damage/4)

      before = System.system_time(:millisecond)
      {:noreply, updated} = MobSession.handle_info(:cast_complete, state)

      assert updated.casting == nil
      assert updated.skill_cooldowns["NPC_FIREATTACK"] >= before + 5_000
      assert updated.ai_timer_ref
    end
  end

  describe "interrupt_cast/1" do
    test "force-cancels an in-flight cast and reports the interrupted skill" do
      # The base row is `cancelable: false`: the interrupt is unconditional, per
      # rAthena's forced unit_skillcastcancel(target, 0) (spellbreaker.cpp:47).
      state =
        build_mob_state()
        |> MobState.set_casting(%{row: row(), complete_at: 0})

      {:reply, reply, updated} = MobSession.handle_call(:interrupt_cast, self(), state)

      assert reply == {:ok, %{skill: "NPC_FIREATTACK", skill_id: 186, level: 3}}
      assert updated.casting == nil
    end

    test "broadcasts a cast cancel, cancels the timer and still writes the delay cooldown" do
      ref = Process.send_after(self(), :cast_complete, 10_000)

      state =
        build_mob_state()
        |> MobState.set_casting(%{row: row(), complete_at: 0, timer_ref: ref})

      test_pid = self()

      expect(Broadcast, :to_in_range, fn "prontera", 100, 100, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      before = System.system_time(:millisecond)
      {:reply, {:ok, _}, updated} = MobSession.handle_call(:interrupt_cast, self(), state)

      assert updated.casting == nil
      assert updated.skill_cooldowns["NPC_FIREATTACK"] >= before + 5_000
      assert_received {:packet, %CastCancel{gid: 1}}
      assert Process.cancel_timer(ref) == false
    end

    test "an idle mob reports :not_casting" do
      state = build_mob_state()

      {:reply, reply, updated} = MobSession.handle_call(:interrupt_cast, self(), state)

      assert reply == {:error, :not_casting}
      assert updated == state
    end

    test "a dead mob mid-cast reports :not_casting and keeps its cast untouched" do
      # handle_death/2 leaves `casting` set and the process lives on until
      # :terminate, so without the is_dead guard a corpse would bill a live cast.
      state =
        build_mob_state(%{is_dead: true})
        |> MobState.set_casting(%{row: row(), complete_at: 0})

      {:reply, reply, updated} = MobSession.handle_call(:interrupt_cast, self(), state)

      assert reply == {:error, :not_casting}
      assert updated.skill_cooldowns == %{}
    end
  end

  describe "zap_sp/2" do
    test "drains the requested SP" do
      state = build_mob_state(%{sp: 50, max_sp: 100})

      {:noreply, updated} = MobSession.handle_cast({:zap_sp, 20}, state)

      assert updated.sp == 30
    end

    test "clamps the drain at 0 rather than going negative" do
      state = build_mob_state(%{sp: 5, max_sp: 100})

      {:noreply, updated} = MobSession.handle_cast({:zap_sp, 20}, state)

      assert updated.sp == 0
    end

    test "a dead mob is left untouched" do
      # The zap lands as a cast after the interrupt's reply, so the mob can die
      # in between; a corpse must not be billed.
      state = build_mob_state(%{sp: 50, max_sp: 100, is_dead: true})

      {:noreply, updated} = MobSession.handle_cast({:zap_sp, 20}, state)

      assert updated.sp == 50
    end

    test "a zero drain is a no-op" do
      state = build_mob_state(%{sp: 50, max_sp: 100})

      {:noreply, updated} = MobSession.handle_cast({:zap_sp, 0}, state)

      assert updated.sp == 50
    end
  end

  describe "interrupt_cast/1 against a live mob process" do
    # The mailbox ordering these assert can only be observed through a real
    # process. The mob is dormant so no AI tick can re-select mid-test, and its
    # target is cleared so a completing cast resolves no target and executes
    # nothing.
    setup do
      state = build_mob_state() |> MobState.set_target(nil)
      {:ok, pid} = MobSession.start_link(%{state: state, awake: false})
      %{pid: pid}
    end

    defp arm_cast(pid, casting) do
      :sys.replace_state(pid, &MobState.set_casting(&1, casting))
    end

    test "a cast that completed first yields :not_casting", %{pid: pid} do
      arm_cast(pid, %{row: row(), complete_at: 0, timer_ref: nil})

      # Enqueued ahead of the call, exactly as the fired timer would be: the mob
      # drains :cast_complete first, so the call must find no cast rather than
      # bill one that already went off.
      send(pid, :cast_complete)

      assert MobSession.interrupt_cast(pid) == {:error, :not_casting}
    end

    test "an interrupt that lands first wins and the completion never fires", %{pid: pid} do
      timer_ref = Process.send_after(pid, :cast_complete, 30_000)
      arm_cast(pid, %{row: row(), complete_at: 0, timer_ref: timer_ref})

      assert {:ok, %{skill: "NPC_FIREATTACK", skill_id: 186, level: 3}} =
               MobSession.interrupt_cast(pid)

      assert MobSession.get_state(pid).casting == nil
      assert Process.read_timer(timer_ref) == false
    end
  end

  describe "silence/stun cast interruption" do
    test "a silence hook mid-cast broadcasts a cast cancel for the mob's gid" do
      # Regression: the abort used to be silent, leaving the client's mob cast
      # bar running forever on every silence/stun interrupt.
      state = build_mob_state() |> MobState.set_casting(%{row: row(), complete_at: 0})
      test_pid = self()

      expect(Broadcast, :to_in_range, fn "prontera", 100, 100, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      {:noreply, updated} = MobSession.handle_cast({:status_changed, :sc_silence, :apply}, state)

      assert updated.casting == nil
      assert_received {:packet, %CastCancel{gid: 1}}
    end

    test "a stun hook mid-cast broadcasts a cast cancel for the mob's gid" do
      state = build_mob_state() |> MobState.set_casting(%{row: row(), complete_at: 0})
      test_pid = self()

      expect(Broadcast, :to_in_range, fn "prontera", 100, 100, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      {:noreply, updated} = MobSession.handle_cast({:status_changed, :sc_stun, :apply}, state)

      assert updated.casting == nil
      assert_received {:packet, %CastCancel{gid: 1}}
    end

    test "a silence hook mid-cast clears casting, cancels the timer and sets the delay cooldown" do
      row = row(%{cast_time: 100})
      stub(MobSkillDb, :rows_for, fn 1001 -> [row] end)

      {:noreply, casting_state} = MobSession.handle_info(:ai_tick, build_mob_state())
      assert %{row: ^row, timer_ref: ref} = casting_state.casting
      assert is_reference(ref)

      before = System.system_time(:millisecond)

      {:noreply, updated} =
        MobSession.handle_cast({:status_changed, :sc_silence, :apply}, casting_state)

      assert updated.casting == nil
      assert updated.skill_cooldowns["NPC_FIREATTACK"] >= before + 5_000
      # The cancelled timer must never deliver :cast_complete (window > cast_time).
      refute_receive :cast_complete, 200
    end

    test "a status_changed for an unrelated status leaves the cast running" do
      ref = Process.send_after(self(), :cast_complete, 10_000)

      state =
        build_mob_state()
        |> MobState.set_casting(%{row: row(), complete_at: 0, timer_ref: ref})

      {:noreply, updated} =
        MobSession.handle_cast({:status_changed, :sc_poison, :tick}, state)

      assert updated.casting == state.casting
      Process.cancel_timer(ref)
    end

    test "a status_changed on a non-casting mob is a no-op" do
      state = build_mob_state()

      {:noreply, updated} =
        MobSession.handle_cast({:status_changed, :sc_stun, :apply}, state)

      assert updated.casting == nil
    end

    @tag :skip
    test "an ai_tick on a stunned mid-cast mob aborts the cast and cancels the timer" do
      ref = Process.send_after(self(), :cast_complete, 100)

      state =
        build_mob_state()
        |> MobState.set_casting(%{row: row(), complete_at: 0, timer_ref: ref})

      stub(StatusStorage, :has_status?, fn
        :mob, 1, :sc_stun -> true
        :mob, _id, _status -> false
      end)

      reject(&Combat.execute_magic_damage/4)

      before = System.system_time(:millisecond)
      {:noreply, updated} = MobSession.handle_info(:ai_tick, state)

      assert updated.casting == nil
      assert updated.skill_cooldowns["NPC_FIREATTACK"] >= before + 5_000
      assert updated.ai_timer_ref
      refute_receive :cast_complete, 200
    end

    test "a silenced mob does not begin a new cast on its ai tick" do
      stub(MobSkillDb, :rows_for, fn 1001 -> [row()] end)

      stub(StatusStorage, :has_status?, fn
        :mob, 1, :sc_silence -> true
        :mob, _id, _status -> false
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, @target_id ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(StatusInterpreter, :targetable?, fn :player, @target_id -> true end)
      stub(StatusInterpreter, :can_attack?, fn :mob, 1 -> true end)
      reject(&Combat.execute_magic_damage/4)
      test_pid = self()

      expect(Combat, :execute_mob_attack, fn _state, @target_id ->
        send(test_pid, :melee)
        :ok
      end)

      {:noreply, updated} = MobSession.handle_info(:ai_tick, build_mob_state())

      assert updated.casting == nil
      assert_received :melee
    end
  end
end
