defmodule Aesir.ZoneServer.Mmo.StatusTickManagerTest do
  @moduledoc """
  Verifies the tick manager's exact per-status deadlines (arming, anchored
  ticks, tick-before-expiry ordering, stale generations) and its post-processing
  notifications: monster lifecycle notifications belong to the interpreter,
  while the player path keeps its `{:stats, :status_changed}` PubSub broadcast.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup :setup_ets_tables

  @moduletag :capture_log

  @mob_id 7001
  @player_id 8_417
  @status :sc_increase_agi

  setup do
    stub(Interpreter, :process_tick, fn _type, _id, _status -> :ok end)
    stub(Interpreter, :process_tick_if_current, fn _type, _id, _status, _generation -> :stop end)

    stub(Interpreter, :expire_status_if_current, fn unit_type, unit_id, status_id, entry ->
      StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, entry)
    end)

    stub(UnitRegistry, :unit_exists?, fn _type, _id -> true end)
    :ok
  end

  defp past, do: System.monotonic_time(:millisecond) - 10_000

  defp tick(state \\ %StatusTickManager.State{}) do
    {:noreply, _new_state} = StatusTickManager.handle_info(:tick, state)
    :ok
  end

  defp stored(unit_type, unit_id, params) do
    :ok = StatusStorage.apply_status(unit_type, unit_id, @status, params)
    StatusStorage.get_status(unit_type, unit_id, @status)
  end

  defp set_deadlines(unit_type, unit_id, next_tick_at, expires_at) do
    :ok =
      StatusStorage.update_status(unit_type, unit_id, @status, fn entry ->
        %{entry | next_tick_at: next_tick_at, expires_at: expires_at}
      end)

    StatusStorage.get_status(unit_type, unit_id, @status)
  end

  defp fire(state, unit_type, unit_id, generation, due_at) do
    {:noreply, new_state} =
      StatusTickManager.handle_info(
        {:status_timer, {unit_type, unit_id, @status}, generation, due_at},
        state
      )

    new_state
  end

  defp armed(state, unit_type, unit_id) do
    {:noreply, new_state} =
      StatusTickManager.handle_cast(
        {:arm, unit_type, unit_id, StatusStorage.get_status(unit_type, unit_id, @status)},
        state
      )

    new_state
  end

  describe "status deadlines" do
    test "arming schedules the earlier of the next tick and the expiry, once per status" do
      now = System.monotonic_time(:millisecond)
      %{generation: generation} = stored(:player, @player_id, tick: 1_000, duration: 60_000)
      entry = set_deadlines(:player, @player_id, now - 1, now + 60_000)

      state = armed(%StatusTickManager.State{}, :player, @player_id)

      key = {:player, @player_id, @status}
      due_at = entry.next_tick_at
      assert {ref, ^generation, ^due_at} = state.timers[key]
      assert_receive {:status_timer, ^key, ^generation, ^due_at}, 50

      again = armed(state, :player, @player_id)
      assert again.timers[key] == {ref, generation, due_at}
    end

    test "re-arming a changed deadline cancels the previous timer" do
      now = System.monotonic_time(:millisecond)
      stored(:player, @player_id, tick: 1_000, duration: 60_000)
      set_deadlines(:player, @player_id, now + 5_000, now + 60_000)
      state = armed(%StatusTickManager.State{}, :player, @player_id)
      {first_ref, _generation, _due_at} = state.timers[{:player, @player_id, @status}]

      set_deadlines(:player, @player_id, now + 7_000, now + 60_000)
      state = armed(state, :player, @player_id)

      assert Process.read_timer(first_ref) == false
      assert {_ref, _generation, due_at} = state.timers[{:player, @player_id, @status}]
      assert due_at == now + 7_000
      assert map_size(state.timers) == 1
    end

    test "a status without deadlines arms nothing" do
      stored(:player, @player_id, tick: 0)

      state = armed(%StatusTickManager.State{}, :player, @player_id)

      assert state.timers == %{}
      refute_receive {:status_timer, _, _, _}, 20
    end

    test "a due tick runs and the next deadline is anchored to the tick deadline" do
      now = System.monotonic_time(:millisecond)
      %{generation: generation} = stored(:player, @player_id, tick: 1_000, duration: 60_000)
      entry = set_deadlines(:player, @player_id, now - 200, now + 60_000)
      due_at = entry.next_tick_at

      expect(Interpreter, :process_tick_if_current, fn
        :player, @player_id, @status, ^generation -> :continue
      end)

      key = {:player, @player_id, @status}
      state = %StatusTickManager.State{timers: %{key => {make_ref(), generation, due_at}}}

      state = fire(state, :player, @player_id, generation, due_at)

      next_due = due_at + 1_000

      assert %{next_tick_at: ^next_due, tick_count: 1} =
               StatusStorage.get_status(:player, @player_id, @status)

      assert {_ref, ^generation, ^next_due} = state.timers[key]
    end

    test "a tick more than a second late anchors its next deadline to the present" do
      now = System.monotonic_time(:millisecond)
      %{generation: generation} = stored(:player, @player_id, tick: 1_000, duration: 60_000)
      entry = set_deadlines(:player, @player_id, now - 5_000, now + 60_000)
      key = {:player, @player_id, @status}

      state = %StatusTickManager.State{
        timers: %{key => {make_ref(), generation, entry.next_tick_at}}
      }

      before = System.monotonic_time(:millisecond)
      fire(state, :player, @player_id, generation, entry.next_tick_at)
      after_tick = System.monotonic_time(:millisecond)

      %{next_tick_at: next_tick_at} = StatusStorage.get_status(:player, @player_id, @status)
      assert next_tick_at in (before + 1_000)..(after_tick + 1_000)
    end

    test "a tick due at the expiry runs before the expiry" do
      player_id = 8_023
      PubSub.subscribe(Aesir.PubSub, "player:#{player_id}")
      test_pid = self()
      now = System.monotonic_time(:millisecond)
      %{generation: generation} = stored(:player, player_id, tick: 1_000, duration: 5_000)
      entry = set_deadlines(:player, player_id, now - 1, now - 1)
      due_at = entry.expires_at

      expect(Interpreter, :process_tick_if_current, fn :player,
                                                       ^player_id,
                                                       @status,
                                                       ^generation ->
        send(test_pid, :ticked)
        :continue
      end)

      expect(Interpreter, :expire_status_if_current, fn :player, ^player_id, @status, expired ->
        send(test_pid, :expired)
        StatusStorage.remove_status_if_current(:player, player_id, @status, expired)
      end)

      key = {:player, player_id, @status}
      state = %StatusTickManager.State{timers: %{key => {make_ref(), generation, due_at}}}

      state = fire(state, :player, player_id, generation, due_at)

      assert_receive {:stats, :status_changed}
      {:messages, messages} = Process.info(self(), :messages)
      assert Enum.filter(messages, &is_atom/1) == [:ticked, :expired]
      refute StatusStorage.has_status?(:player, player_id, @status)
      refute Map.has_key?(state.timers, key)
    end

    test "an expiry pushed later re-arms instead of expiring" do
      now = System.monotonic_time(:millisecond)
      %{generation: generation} = stored(:player, @player_id, duration: 5_000)
      entry = set_deadlines(:player, @player_id, nil, now - 1)
      due_at = entry.expires_at
      reject(&Interpreter.expire_status_if_current/4)

      key = {:player, @player_id, @status}
      state = %StatusTickManager.State{timers: %{key => {make_ref(), generation, due_at}}}
      extended = set_deadlines(:player, @player_id, nil, now + 3_000)

      state = fire(state, :player, @player_id, generation, due_at)

      assert StatusStorage.has_status?(:player, @player_id, @status)
      assert {_ref, ^generation, due} = state.timers[key]
      assert due == extended.expires_at
    end

    test "a deadline of a stale generation re-arms its replacement without touching it" do
      now = System.monotonic_time(:millisecond)
      %{generation: generation} = stored(:player, @player_id, tick: 1_000, duration: 5_000)
      set_deadlines(:player, @player_id, now - 1, now + 4_000)
      reject(&Interpreter.process_tick_if_current/4)
      reject(&Interpreter.expire_status_if_current/4)

      key = {:player, @player_id, @status}
      stale = 1
      state = %StatusTickManager.State{timers: %{key => {make_ref(), stale, now - 1}}}

      state = fire(state, :player, @player_id, stale, now - 1)

      assert StatusStorage.has_status?(:player, @player_id, @status)
      assert {_ref, ^generation, due_at} = state.timers[key]
      assert due_at == now - 1
    end

    test "arming an older generation never replaces a newer pending timer" do
      now = System.monotonic_time(:millisecond)
      older = stored(:player, @player_id, tick: 1_000, duration: 60_000)
      :ok = StatusStorage.remove_status(:player, @player_id, @status)
      %{generation: newer} = stored(:player, @player_id, tick: 1_000, duration: 60_000)
      set_deadlines(:player, @player_id, now + 100, now + 60_000)
      state = armed(%StatusTickManager.State{}, :player, @player_id)
      {ref, ^newer, due_at} = state.timers[{:player, @player_id, @status}]

      {:noreply, state} =
        StatusTickManager.handle_cast(
          {:arm, :player, @player_id, %{older | next_tick_at: now + 5_000}},
          state
        )

      assert state.timers[{:player, @player_id, @status}] == {ref, newer, due_at}
      assert Process.read_timer(ref)
    end

    test "a deadline that was re-armed since it fired is ignored" do
      now = System.monotonic_time(:millisecond)
      %{generation: generation} = stored(:player, @player_id, duration: 5_000)
      set_deadlines(:player, @player_id, nil, now - 1)
      reject(&Interpreter.expire_status_if_current/4)

      key = {:player, @player_id, @status}
      current = {make_ref(), generation, now + 3_000}
      state = %StatusTickManager.State{timers: %{key => current}}

      state = fire(state, :player, @player_id, generation, now - 1)

      assert state.timers[key] == current
    end

    test "init arms the statuses already in storage" do
      now = System.monotonic_time(:millisecond)
      %{generation: generation} = stored(:mob, @mob_id, tick: 1_000, duration: 60_000)
      entry = set_deadlines(:mob, @mob_id, now + 1_000, now + 60_000)

      assert {:ok, state} = StatusTickManager.init([])

      due_at = entry.next_tick_at
      assert {_ref, ^generation, ^due_at} = state.timers[{:mob, @mob_id, @status}]
    end
  end

  describe "exact status ticks" do
    test "schedules the first deadline at started_at plus 1,000 ms" do
      started_at = System.monotonic_time(:millisecond) - 1_000
      due_at = started_at + 1_000
      state = %StatusTickManager.State{}

      assert {:noreply, ^state} =
               StatusTickManager.handle_cast(
                 {:schedule_exact_tick, :player, @player_id, @status, 41, due_at},
                 state
               )

      assert_receive {:exact_status_tick, :player, @player_id, @status, 41, ^due_at}, 50
    end

    test "continuation advances from the prior deadline without handler drift" do
      due_at = System.monotonic_time(:millisecond) - 5_000
      next_due_at = due_at + 500
      state = %StatusTickManager.State{}

      expect(Interpreter, :process_tick_if_current, fn
        :player, @player_id, @status, 42 -> :continue
      end)

      assert {:noreply, ^state} =
               StatusTickManager.handle_info(
                 {:exact_status_tick, :player, @player_id, @status, 42, due_at},
                 state
               )

      assert_receive {:exact_status_tick, :player, @player_id, @status, 42, ^next_due_at}
    end

    test "a stale exact tick stops without scheduling another deadline" do
      due_at = System.monotonic_time(:millisecond) - 5_000
      state = %StatusTickManager.State{}

      expect(Interpreter, :process_tick_if_current, fn
        :player, @player_id, @status, 43 -> :stop
      end)

      assert {:noreply, ^state} =
               StatusTickManager.handle_info(
                 {:exact_status_tick, :player, @player_id, @status, 43, due_at},
                 state
               )

      refute_receive {:exact_status_tick, :player, @player_id, @status, 43, _}
    end

    test "the global poll does not process a tickless exact status" do
      reject(&Interpreter.process_tick/3)
      :ok = StatusStorage.apply_status(:player, @player_id, @status, tick: 0)

      tick()

      assert %{next_tick_at: nil} = StatusStorage.get_status(:player, @player_id, @status)
    end
  end

  describe "mob notifications" do
    test "expiry does not duplicate the interpreter's monster lifecycle notification" do
      test_pid = self()
      stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:ok, {MobState, %{}, test_pid}} end)

      :ok = StatusStorage.apply_status(:mob, @mob_id, @status)
      :ok = StatusStorage.update_status(:mob, @mob_id, @status, &%{&1 | expires_at: past()})

      tick()

      refute StatusStorage.has_status?(:mob, @mob_id, @status)
      refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
    end

    test "a due mob tick does not request calculated stats" do
      test_pid = self()
      stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:ok, {MobState, %{}, test_pid}} end)

      :ok = StatusStorage.apply_status(:mob, @mob_id, @status)
      :ok = StatusStorage.update_next_tick(:mob, @mob_id, @status, past())

      tick()

      assert %{tick_count: 1} = StatusStorage.get_status(:mob, @mob_id, @status)
      refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
    end

    test "an unregistered mob session is a silent no-op" do
      stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:error, :not_found} end)

      :ok = StatusStorage.apply_status(:mob, @mob_id, @status)
      :ok = StatusStorage.update_status(:mob, @mob_id, @status, &%{&1 | expires_at: past()})

      assert tick() == :ok
    end
  end

  describe "orphaned statuses" do
    test "a due status of a unit missing from the registry is cleared, not processed" do
      stub(UnitRegistry, :unit_exists?, fn :player, @player_id -> false end)
      reject(&Interpreter.process_tick/3)

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_next_tick(:player, @player_id, @status, past())

      tick()

      assert StatusStorage.get_unit_statuses(:player, @player_id) == []
    end

    test "an expired status of a unit missing from the registry is cleared, not processed" do
      stub(UnitRegistry, :unit_exists?, fn :player, @player_id -> false end)
      reject(&Interpreter.expire_status_if_current/4)

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_status(:player, @player_id, @status, &%{&1 | expires_at: past()})

      tick()

      assert StatusStorage.get_unit_statuses(:player, @player_id) == []
    end

    test "an orphan's statuses end through their end logic" do
      test_pid = self()
      stub(UnitRegistry, :unit_exists?, fn :mob, @mob_id -> false end)

      stub(Aesir.ZoneServer.Mmo.Skill.Unit, :destroy_async, fn group_id ->
        send(test_pid, {:destroyed, group_id})
      end)

      :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_dancing, val1: 1, val2: 77)
      :ok = StatusStorage.apply_status(:mob, @mob_id, @status)
      :ok = StatusStorage.update_next_tick(:mob, @mob_id, @status, past())

      tick()

      assert_received {:destroyed, 77}
      assert StatusStorage.get_unit_statuses(:mob, @mob_id) == []
    end

    test "the tick manager keeps processing other units after clearing an orphan" do
      test_pid = self()
      stub(UnitRegistry, :unit_exists?, fn _type, id -> id == @mob_id end)
      stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:ok, {MobState, %{}, test_pid}} end)

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_next_tick(:player, @player_id, @status, past())
      :ok = StatusStorage.apply_status(:mob, @mob_id, @status)
      :ok = StatusStorage.update_next_tick(:mob, @mob_id, @status, past())

      tick()

      assert StatusStorage.get_unit_statuses(:player, @player_id) == []
      assert %{tick_count: 1} = StatusStorage.get_status(:mob, @mob_id, @status)
      refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
    end
  end

  describe "player path is unchanged" do
    test "a positive finite status remains active until its expiry" do
      PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")

      :ok = StatusStorage.apply_status(:player, @player_id, @status, duration: 60_000)
      assert is_integer(StatusStorage.get_status(:player, @player_id, @status).expires_at)

      tick()

      assert StatusStorage.has_status?(:player, @player_id, @status)
      refute_receive {:stats, :status_changed}

      :ok = StatusStorage.update_status(:player, @player_id, @status, &%{&1 | expires_at: past()})
      tick()

      refute StatusStorage.has_status?(:player, @player_id, @status)
      assert_receive {:stats, :status_changed}
    end

    test "an expired player status still broadcasts one lifecycle refresh and no cast" do
      PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_status(:player, @player_id, @status, &%{&1 | expires_at: past()})

      tick()

      assert_receive {:stats, :status_changed}
      refute_receive {:stats, :status_changed}
      refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
    end

    test "a captured expired generation cannot remove or notify for its fresh replacement" do
      test_pid = self()
      stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:ok, {MobState, %{}, test_pid}} end)

      :ok = StatusStorage.apply_status(:mob, @mob_id, @status)
      :ok = StatusStorage.update_status(:mob, @mob_id, @status, &%{&1 | expires_at: past()})
      expired = StatusStorage.get_status(:mob, @mob_id, @status)

      stub(Interpreter, :expire_status_if_current, fn :mob, @mob_id, @status, ^expired ->
        {:stored, fresh, _prior} = StatusStorage.apply_status_with_entry(:mob, @mob_id, @status)
        send(test_pid, {:fresh_generation, fresh})

        call_original(Interpreter, :expire_status_if_current, [:mob, @mob_id, @status, expired])
      end)

      tick()

      assert_receive {:fresh_generation, fresh}
      assert StatusStorage.get_status(:mob, @mob_id, @status) === fresh
      refute_receive {:"$gen_cast", {:casting, {:status_changed, @status, :expired}}}
    end

    test "a due player status still broadcasts {:stats, :status_changed}" do
      PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_next_tick(:player, @player_id, @status, past())

      tick()

      assert_receive {:stats, :recalculate}
    end

    test "the sweep processes a long-overdue tick and re-arms it a second out" do
      :ok = StatusStorage.apply_status(:player, @player_id, @status, tick: 1_000)
      :ok = StatusStorage.update_next_tick(:player, @player_id, @status, past())
      %{generation: generation} = StatusStorage.get_status(:player, @player_id, @status)

      expect(Interpreter, :process_tick_if_current, fn :player,
                                                       @player_id,
                                                       @status,
                                                       ^generation ->
        :continue
      end)

      before_tick = System.monotonic_time(:millisecond)

      {:noreply, state} = StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

      after_tick = System.monotonic_time(:millisecond)
      entry = StatusStorage.get_status(:player, @player_id, @status)
      assert entry.next_tick_at in (before_tick + 1_000)..(after_tick + 1_000)
      assert {_ref, ^generation, due_at} = state.timers[{:player, @player_id, @status}]
      assert due_at == entry.next_tick_at
    end
  end
end
