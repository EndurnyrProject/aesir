defmodule Aesir.ZoneServer.Mmo.StatusTickManagerTest do
  @moduledoc """
  Verifies the tick manager's post-processing notifications: a mob whose status
  ticks or expires gets a `{:casting, {:status_changed, status_id, event}}` cast
  on its MobSession, while the player path keeps its `:recalculate_stats` PubSub
  broadcast untouched.
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
  @player_id 8001
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
    test "an expired mob status casts {:casting, {:status_changed, status_id, :expired}} to its session" do
      test_pid = self()
      stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:ok, {MobState, %{}, test_pid}} end)

      :ok = StatusStorage.apply_status(:mob, @mob_id, @status)
      :ok = StatusStorage.update_status(:mob, @mob_id, @status, &%{&1 | expires_at: past()})

      tick()

      assert_receive {:"$gen_cast", {:casting, {:status_changed, @status, :expired}}}
    end

    test "a due mob status casts {:casting, {:status_changed, status_id, :tick}} to its session" do
      test_pid = self()
      stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:ok, {MobState, %{}, test_pid}} end)

      :ok = StatusStorage.apply_status(:mob, @mob_id, @status)
      :ok = StatusStorage.update_next_tick(:mob, @mob_id, @status, past())

      tick()

      assert_receive {:"$gen_cast", {:casting, {:status_changed, @status, :tick}}}
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
      assert_receive {:"$gen_cast", {:casting, {:status_changed, @status, :tick}}}
    end
  end

  describe "player path is unchanged" do
    test "a positive finite status remains active until its expiry" do
      PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")

      :ok = StatusStorage.apply_status(:player, @player_id, @status, duration: 60_000)
      assert is_integer(StatusStorage.get_status(:player, @player_id, @status).expires_at)

      tick()

      assert StatusStorage.has_status?(:player, @player_id, @status)
      refute_receive :recalculate_stats

      :ok = StatusStorage.update_status(:player, @player_id, @status, &%{&1 | expires_at: past()})
      tick()

      refute StatusStorage.has_status?(:player, @player_id, @status)
      assert_receive :recalculate_stats
    end

    test "an expired player status still broadcasts one lifecycle refresh and no cast" do
      PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_status(:player, @player_id, @status, &%{&1 | expires_at: past()})

      tick()

      assert_receive :recalculate_stats
      refute_receive :recalculate_stats
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

    test "a due player status still broadcasts :recalculate_stats" do
      PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_next_tick(:player, @player_id, @status, past())

      tick()

      assert_receive {:stats, :recalculate}
    end

    test "ordinary statuses retain their 1,000 ms polling cadence" do
      expect(Interpreter, :process_tick, fn :player, @player_id, @status -> :ok end)
      :ok = StatusStorage.apply_status(:player, @player_id, @status, tick: 1_000)
      :ok = StatusStorage.update_next_tick(:player, @player_id, @status, past())
      before_tick = System.monotonic_time(:millisecond)

      tick()

      after_tick = System.monotonic_time(:millisecond)
      entry = StatusStorage.get_status(:player, @player_id, @status)
      assert entry.next_tick_at in (before_tick + 1_000)..(after_tick + 1_000)
    end
  end
end
