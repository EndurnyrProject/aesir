defmodule Aesir.ZoneServer.Npc.SessionTest do
  @moduledoc """
  Covers `Npc.Session`'s rAthena timer model (schedule derivation, ordered
  fires, idle-after-schedule, stop/freeze/resume), the ETS-mirrored
  enabled/hidden flags, `ensure_started/1` idempotency, and the blank-state
  restart after a crash.
  """

  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session
  alias Aesir.ZoneServer.Npc.SessionDynamicSupervisor

  @flags_table :npc_session_flags

  defmodule TimerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 900, y: 900, dir: 0, sprite: 58, name: "TimerNpc"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer50", ctx), do: ctx
    def on_event("OnTimer120", ctx), do: ctx
    def on_event("OnStart", ctx), do: ctx
  end

  defmodule NoTimerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 901, y: 901, dir: 0, sprite: 58, name: "NoTimerNpc"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule StaleTimerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 903, y: 903, dir: 0, sprite: 58, name: "StaleTimerNpc"}]

    @impl true
    def on_talk(ctx), do: ctx

    # A delay far past this test's timing budget: the real schedule entry
    # never legitimately fires during the test, so any {:fired, ...} message
    # observed can only come from a stale/forged replay slipping through.
    @impl true
    def on_event("OnTimer1000", ctx), do: ctx
  end

  defmodule DispatchedNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 902, y: 902, dir: 0, sprite: 58, name: "DispatchedNpc"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer30", ctx) do
      send(:npc_session_test_probe, {:dispatched, ctx.npc_gid})
      ctx
    end
  end

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([TimerNpc, NoTimerNpc, StaleTimerNpc])
    :ok
  end

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end

  defp start_test_session(gid, on_fire) do
    child_spec = %{
      id: make_ref(),
      start: {Session, :start_link, [[gid: gid, on_fire: on_fire]]},
      restart: :temporary
    }

    start_supervised!(child_spec)
  end

  defp start_via_dynamic_supervisor(gid) do
    pid = Session.ensure_started(gid)

    on_exit(fn -> stop_current_session(gid) end)

    pid
  end

  # Looked up fresh at teardown time, not captured at start time: a crash
  # test's automatic restart replaces the pid this helper originally
  # returned, and terminating the stale (already dead) one would leave the
  # replacement running for the rest of the suite.
  defp stop_current_session(gid) do
    case Registry.lookup(Aesir.ZoneServer.Npc.SessionRegistry, gid) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(SessionDynamicSupervisor, pid)
      [] -> :ok
    end
  end

  defp wait_for_new_pid(gid, old_pid, deadline \\ System.monotonic_time(:millisecond) + 500)

  defp wait_for_new_pid(gid, old_pid, deadline) do
    case Registry.lookup(Aesir.ZoneServer.Npc.SessionRegistry, gid) do
      [{^old_pid, _}] ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(5)
          wait_for_new_pid(gid, old_pid, deadline)
        else
          flunk("session for gid #{gid} was never restarted")
        end

      [{new_pid, _}] ->
        new_pid

      [] ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(5)
          wait_for_new_pid(gid, old_pid, deadline)
        else
          flunk("session for gid #{gid} was never restarted")
        end
    end
  end

  describe "ensure_started/1" do
    test "is idempotent: repeated calls for the same gid return the same pid" do
      gid = gid_for(NoTimerNpc)

      pid = start_via_dynamic_supervisor(gid)

      assert Session.ensure_started(gid) == pid
      assert Session.ensure_started(gid) == pid
    end
  end

  describe "init_timer/1" do
    test "fires each OnTimer label in order at roughly the right elapsed time, then goes idle" do
      gid = gid_for(TimerNpc)
      test_pid = self()

      start_test_session(gid, fn fired_gid, label ->
        send(test_pid, {:fired, fired_gid, label})
      end)

      :ok = Session.init_timer(gid)

      assert_receive {:fired, ^gid, "OnTimer50"}, 300
      assert_receive {:fired, ^gid, "OnTimer120"}, 300

      refute_receive {:fired, ^gid, _label}, 150

      elapsed = Session.get_timer(gid)
      assert elapsed >= 120
    end

    test "a module with no OnTimer labels goes idle immediately with nothing scheduled" do
      gid = gid_for(NoTimerNpc)
      test_pid = self()

      start_test_session(gid, fn fired_gid, label ->
        send(test_pid, {:fired, fired_gid, label})
      end)

      :ok = Session.init_timer(gid)

      refute_receive {:fired, ^gid, _label}, 100
    end
  end

  describe "stop_timer/1 and get_timer/1" do
    test "stop freezes elapsed, get_timer reads it, and re-init_timer restarts from 0" do
      gid = gid_for(TimerNpc)
      test_pid = self()

      start_test_session(gid, fn fired_gid, label ->
        send(test_pid, {:fired, fired_gid, label})
      end)

      :ok = Session.init_timer(gid)
      assert_receive {:fired, ^gid, "OnTimer50"}, 300

      :ok = Session.stop_timer(gid)
      frozen = Session.get_timer(gid)
      assert frozen >= 50

      Process.sleep(30)
      assert Session.get_timer(gid) == frozen

      refute_receive {:fired, ^gid, "OnTimer120"}, 150

      :ok = Session.init_timer(gid)
      assert Session.get_timer(gid) < frozen
    end

    test "get_timer/1 for a gid with no session returns 0 without spawning one" do
      gid = gid_for(NoTimerNpc)

      assert Session.get_timer(gid) == 0
      assert Registry.lookup(Aesir.ZoneServer.Npc.SessionRegistry, gid) == []
    end

    test "stop_timer/1 for a gid with no session returns :ok without spawning one" do
      gid = gid_for(TimerNpc)

      assert Session.stop_timer(gid) == :ok
      assert Registry.lookup(Aesir.ZoneServer.Npc.SessionRegistry, gid) == []
    end
  end

  describe "enabled?/1 and hidden?/1" do
    test "read directly from ETS with no session and no GenServer call" do
      gid = gid_for(NoTimerNpc)

      assert Session.enabled?(gid)
      refute Session.hidden?(gid)

      :ets.insert(@flags_table, {gid, false, true})
      on_exit(fn -> :ets.delete(@flags_table, gid) end)

      refute Session.enabled?(gid)
      assert Session.hidden?(gid)
      assert Registry.lookup(Aesir.ZoneServer.Npc.SessionRegistry, gid) == []
    end

    test "set_enabled/2 and set_hidden/2 write GenServer state and mirror to ETS" do
      gid = gid_for(NoTimerNpc)
      start_via_dynamic_supervisor(gid)

      :ok = Session.set_enabled(gid, false)
      :ok = Session.set_hidden(gid, true)

      refute Session.enabled?(gid)
      assert Session.hidden?(gid)
    end
  end

  describe "a crashed session" do
    test "restarts blank: timer stopped, flags reset" do
      gid = gid_for(TimerNpc)
      pid = start_via_dynamic_supervisor(gid)

      :ok = Session.init_timer(gid)
      :ok = Session.set_enabled(gid, false)
      :ok = Session.set_hidden(gid, true)

      ref = Process.monitor(pid)
      GenServer.cast(pid, :boom)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500

      new_pid = wait_for_new_pid(gid, pid)
      assert new_pid != pid

      assert Session.get_timer(gid) == 0
      assert Session.enabled?(gid)
      refute Session.hidden?(gid)
    end
  end

  describe "stale :timer_fire messages" do
    test "a forged ref, and an old real ref replayed after stop_timer, are both ignored" do
      gid = gid_for(StaleTimerNpc)
      test_pid = self()

      pid =
        start_test_session(gid, fn fired_gid, label ->
          send(test_pid, {:fired, fired_gid, label})
        end)

      :ok = Session.init_timer(gid)

      send(pid, {:timer_fire, make_ref(), "OnTimer1000"})
      refute_receive {:fired, ^gid, _label}, 50

      real_ref = :sys.get_state(pid).timer_ref
      :ok = Session.stop_timer(gid)

      send(pid, {:timer_fire, real_ref, "OnTimer1000"})
      refute_receive {:fired, ^gid, _label}, 50

      assert Session.get_timer(gid) == :sys.get_state(pid).frozen_elapsed
    end
  end

  describe "default :on_fire" do
    test "a timer fire on a real registered NPC runs its on_event handler through Events" do
      NpcRegistry.reload([DispatchedNpc])
      Process.register(self(), :npc_session_test_probe)

      {DispatchedNpc, placement} = hd(NpcRegistry.entries())
      gid = NpcRegistry.entity_id(placement)

      start_via_dynamic_supervisor(gid)

      :ok = Session.init_timer(gid)

      assert_receive {:dispatched, ^gid}, 300
    end
  end
end
