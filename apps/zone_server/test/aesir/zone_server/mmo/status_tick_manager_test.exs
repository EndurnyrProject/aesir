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

    stub(Interpreter, :remove_statuses, fn unit_type,
                                           unit_id,
                                           status_ids,
                                           [owner_refresh: :notify] ->
      Enum.each(status_ids, &StatusStorage.remove_status(unit_type, unit_id, &1))

      if unit_type == :player do
        PubSub.broadcast(Aesir.PubSub, "player:#{unit_id}", :recalculate_stats)
      end

      :ok
    end)

    stub(UnitRegistry, :unit_exists?, fn _type, _id -> true end)
    :ok
  end

  defp past, do: System.monotonic_time(:millisecond) - 10_000

  defp tick(state \\ %StatusTickManager.State{}) do
    {:noreply, _new_state} = StatusTickManager.handle_info(:tick, state)
    :ok
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
      reject(&Interpreter.remove_statuses/4)

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
    test "an expired player status still broadcasts :recalculate_stats and no cast" do
      PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_status(:player, @player_id, @status, &%{&1 | expires_at: past()})

      tick()

      assert_receive :recalculate_stats
      refute_receive :recalculate_stats
      refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
    end

    test "a due player status still broadcasts :recalculate_stats" do
      PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")

      :ok = StatusStorage.apply_status(:player, @player_id, @status)
      :ok = StatusStorage.update_next_tick(:player, @player_id, @status, past())

      tick()

      assert_receive {:stats, :recalculate}
    end
  end
end
