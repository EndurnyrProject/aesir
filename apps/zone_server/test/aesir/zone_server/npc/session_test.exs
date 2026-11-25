defmodule Aesir.ZoneServer.Npc.SessionTest do
  @moduledoc """
  Covers `Npc.Session`'s rAthena timer model (schedule derivation, ordered
  fires, idle-after-schedule, stop/freeze/resume, and the player-attached
  timer routing and run swap), the ETS-mirrored
  enabled/hidden flags, `ensure_started/1` idempotency, and the blank-state
  restart after a crash.
  """

  use ExUnit.Case, async: false

  import Aesir.TestWait
  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session
  alias Aesir.ZoneServer.Npc.SessionDynamicSupervisor
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

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

  defmodule ZeroTimerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 904, y: 904, dir: 0, sprite: 58, name: "ZeroTimerNpc"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer0", ctx), do: ctx
    def on_event("OnTimer30", ctx), do: ctx
  end

  defmodule DisabledNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 905, y: 905, sprite: 58, name: "Disabled", state: :disabled}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule HiddenNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 906, y: 906, sprite: 58, name: "Hidden", state: :hidden}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule CloakedNpc do
    use Aesir.ZoneServer.Npc, spawn: [%{name: "Cloaked", state: :cloaked}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)

    NpcRegistry.reload([
      TimerNpc,
      NoTimerNpc,
      StaleTimerNpc,
      ZeroTimerNpc,
      DisabledNpc,
      HiddenNpc,
      CloakedNpc
    ])

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

  describe "start_timer/1" do
    test "resumes a stopped timer from its frozen elapsed time, firing only later labels" do
      gid = gid_for(TimerNpc)
      test_pid = self()

      start_test_session(gid, fn fired_gid, label ->
        send(test_pid, {:fired, fired_gid, label})
      end)

      :ok = Session.init_timer(gid)
      assert_receive {:fired, ^gid, "OnTimer50"}, 300
      :ok = Session.stop_timer(gid)
      frozen = Session.get_timer(gid)

      :ok = Session.start_timer(gid)

      assert Session.get_timer(gid) >= frozen
      assert_receive {:fired, ^gid, "OnTimer120"}, 300
      refute_received {:fired, ^gid, "OnTimer50"}
    end

    test "leaves a running timer alone instead of restarting it" do
      gid = gid_for(TimerNpc)
      start_test_session(gid, fn _gid, _label -> :ok end)

      :ok = Session.init_timer(gid)
      Process.sleep(30)
      :ok = Session.start_timer(gid)

      assert Session.get_timer(gid) >= 30
    end
  end

  describe "set_timer/2" do
    test "sets a stopped timer's elapsed time without starting it" do
      gid = gid_for(TimerNpc)
      test_pid = self()

      start_test_session(gid, fn fired_gid, label ->
        send(test_pid, {:fired, fired_gid, label})
      end)

      :ok = Session.set_timer(gid, 100)

      assert Session.get_timer(gid) == 100
      refute_receive {:fired, ^gid, _label}, 150

      :ok = Session.start_timer(gid)

      assert_receive {:fired, ^gid, "OnTimer120"}, 300
      refute_received {:fired, ^gid, "OnTimer50"}
    end

    test "restarts a running timer from the tick, skipping the labels at or before it" do
      gid = gid_for(TimerNpc)
      test_pid = self()

      start_test_session(gid, fn fired_gid, label ->
        send(test_pid, {:fired, fired_gid, label})
      end)

      :ok = Session.init_timer(gid)
      :ok = Session.set_timer(gid, 50)

      assert Session.get_timer(gid) >= 50
      assert_receive {:fired, ^gid, "OnTimer120"}, 300
      refute_received {:fired, ^gid, "OnTimer50"}
    end
  end

  describe "init_timer/1 with an OnTimer0 label" do
    test "never fires it, as the reference arms only labels due after the start time" do
      gid = gid_for(ZeroTimerNpc)
      test_pid = self()

      start_test_session(gid, fn fired_gid, label ->
        send(test_pid, {:fired, fired_gid, label})
      end)

      :ok = Session.init_timer(gid)

      assert_receive {:fired, ^gid, "OnTimer30"}, 300
      refute_received {:fired, ^gid, "OnTimer0"}
    end
  end

  describe "enabled?/1 and hidden?/1" do
    test "read directly from ETS with no session and no GenServer call" do
      gid = gid_for(NoTimerNpc)

      assert Session.enabled?(gid)
      refute Session.hidden?(gid)

      :ets.insert(@flags_table, {gid, false, true, false})
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

    test "set_enabled/2 also sets or clears the hide and leaves the cloak" do
      gid = gid_for(NoTimerNpc)
      start_via_dynamic_supervisor(gid)

      :ok = Session.set_cloaked(gid, true)
      :ok = Session.set_enabled(gid, false)
      assert Session.hidden?(gid)

      :ok = Session.set_enabled(gid, true)
      refute Session.hidden?(gid)
      assert Session.cloaked?(gid)
    end

    test "touchable?/1 is blocked by a disable or a cloak, not by a hide" do
      gid = gid_for(NoTimerNpc)
      on_exit(fn -> :ets.delete(@flags_table, gid) end)

      for {row, expected} <- [
            {{gid, true, false, false}, true},
            {{gid, true, true, false}, true},
            {{gid, true, false, true}, false},
            {{gid, false, true, false}, false}
          ] do
        :ets.insert(@flags_table, row)
        assert Session.touchable?(gid) == expected, "row #{inspect(row)}"
      end
    end
  end

  describe "a placement's starting state" do
    test "is what the flags read with no session: a disable also hides" do
      for {module, enabled?, hidden?, cloaked?, touchable?} <- [
            {DisabledNpc, false, true, false, false},
            {HiddenNpc, true, true, false, true},
            {CloakedNpc, true, false, true, false}
          ] do
        gid = gid_for(module)

        assert {Session.enabled?(gid), Session.hidden?(gid), Session.cloaked?(gid)} ==
                 {enabled?, hidden?, cloaked?},
               inspect(module)

        refute Session.visible?(gid)
        assert Session.touchable?(gid) == touchable?
      end
    end

    test "a warp portal reads its own warp(<STATE>) flag while no session holds its flags" do
      for {state, visible?, touchable?, hidden?} <- [
            {nil, true, true, false},
            {:disabled, false, false, true},
            {:hidden, false, true, true},
            {:cloaked, false, false, false}
          ] do
        warp = build(:warp, state: state)

        assert {Session.visible?(warp), Session.touchable?(warp), Session.hidden?(warp)} ==
                 {visible?, touchable?, hidden?},
               inspect(state)
      end
    end

    test "is where a started session begins, so script commands change it from there" do
      hidden = gid_for(HiddenNpc)
      start_via_dynamic_supervisor(hidden)
      :ok = Session.set_cloaked(hidden, false)
      assert Session.hidden?(hidden)

      disabled = gid_for(DisabledNpc)
      start_via_dynamic_supervisor(disabled)
      :ok = Session.set_enabled(disabled, true)
      assert Session.visible?(disabled)
    end
  end

  describe "display_override/1 and set_display/2" do
    test "reads nil from ETS with no session" do
      gid = gid_for(NoTimerNpc)
      assert Session.display_override(gid) == nil
    end

    test "set_display/2 merges partial overrides and mirrors them to ETS" do
      gid = gid_for(NoTimerNpc)
      start_via_dynamic_supervisor(gid)

      :ok = Session.set_display(gid, %{sprite: 937})
      assert Session.display_override(gid) == {937, nil, 0}

      :ok = Session.set_display(gid, %{name: "Elite Guard", size: 2})
      assert Session.display_override(gid) == {937, "Elite Guard", 2}
    end
  end

  describe "a crashed session" do
    @tag :capture_log
    test "restarts blank: timer stopped, flags reset" do
      gid = gid_for(TimerNpc)
      pid = start_via_dynamic_supervisor(gid)

      :ok = Session.init_timer(gid)
      :ok = Session.set_enabled(gid, false)
      :ok = Session.set_hidden(gid, true)
      :ok = Session.set_display(gid, %{sprite: 937})

      ref = Process.monitor(pid)
      GenServer.cast(pid, :boom)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500

      new_pid = wait_for_new_pid(gid, pid)
      assert new_pid != pid

      assert Session.get_timer(gid) == 0
      assert Session.enabled?(gid)
      refute Session.hidden?(gid)
      assert Session.display_override(gid) == nil
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

      {real_ref, _deadline, _due_ms} = :sys.get_state(pid).armed
      :ok = Session.stop_timer(gid)

      send(pid, {:timer_fire, real_ref, "OnTimer1000"})
      refute_receive {:fired, ^gid, _label}, 50

      assert Session.get_timer(gid) == :sys.get_state(pid).timer
    end
  end

  describe "default :on_fire" do
    test "a timer fire on a real registered NPC runs its on_event handler through Events" do
      NpcRegistry.reload([DispatchedNpc])
      Aesir.TestProbe.register!(:npc_session_test_probe)

      {DispatchedNpc, placement} = hd(NpcRegistry.entries())
      gid = NpcRegistry.entity_id(placement)

      start_via_dynamic_supervisor(gid)

      :ok = Session.init_timer(gid)

      assert_receive {:dispatched, ^gid}, 300
    end
  end

  # rAthena `initnpctimer`/`startnpctimer`/`stopnpctimer` with an attached
  # `nd->u.scr.rid` (script.cpp) and `npc_timerevent_start`/`_stop` (npc.cpp).
  # The player's session is this test process, so its slot commands arrive as
  # casts.
  describe "player-attached timers" do
    setup do
      char_id = register_player(self())
      gid = gid_for(TimerNpc)
      test_pid = self()
      pid = start_test_session(gid, fn _gid, label -> send(test_pid, {:fired, label}) end)
      {:ok, char_id: char_id, gid: gid, pid: pid}
    end

    test "the attach flag arms the player's slot from 0 and leaves a stopped NPC timer stopped",
         %{char_id: char_id, gid: gid, pid: pid} do
      :ok = Session.init_timer(gid, char_id)

      assert_receive {:"$gen_cast", {:npc, {:timer_start, ^gid, 0, ^pid}}}
      refute_receive {:fired, _label}, 100
      assert Session.get_timer(gid) == 0
    end

    test "an attached init restarts a running NPC timer from 0", %{char_id: char_id, gid: gid} do
      :ok = Session.init_timer(gid)
      assert_receive {:fired, "OnTimer50"}, 300

      :ok = Session.init_timer(gid, char_id)

      assert Session.get_timer(gid) < 50
      assert_receive {:fired, "OnTimer50"}, 300
    end

    test "with a player attached, plain commands act on the slot until a detaching stop",
         %{char_id: char_id, gid: gid, pid: pid} do
      :ok = Session.init_timer(gid, char_id)
      assert_receive {:"$gen_cast", {:npc, {:timer_start, ^gid, 0, ^pid}}}

      :ok = Session.stop_timer(gid)
      assert_receive {:"$gen_cast", {:npc, :timer_stop}}

      :ok = Session.init_timer(gid)
      assert_receive {:"$gen_cast", {:npc, {:timer_start, ^gid, 0, ^pid}}}
      refute_receive {:fired, _label}, 100

      :ok = Session.stop_timer(gid, true)
      refute_received {:"$gen_cast", _}

      :ok = Session.init_timer(gid)
      assert_receive {:fired, "OnTimer50"}, 300
      refute_received {:"$gen_cast", _}
    end

    test "an attached start resumes the slot from the stopped NPC timer's frozen time",
         %{char_id: char_id, gid: gid, pid: pid} do
      :ok = Session.init_timer(gid)
      assert_receive {:fired, "OnTimer50"}, 300
      :ok = Session.stop_timer(gid)
      frozen = Session.get_timer(gid)

      :ok = Session.start_timer(gid, char_id)

      assert_receive {:"$gen_cast", {:npc, {:timer_start, ^gid, ^frozen, ^pid}}}
    end

    @tag :capture_log
    test "an offline attached player makes the slot commands no-ops", %{gid: gid} do
      offline_char_id = System.unique_integer([:positive]) + 1_000_000_000

      :ok = Session.init_timer(gid, offline_char_id)
      :ok = Session.stop_timer(gid)

      refute_receive {:"$gen_cast", _}, 50
      refute_received {:fired, _label}
    end

    test "an attached run swaps in its player and slot time, then restores the attached player",
         %{char_id: char_id, gid: gid} do
      test_pid = self()
      other_pid = spawn_link(fn -> forward_casts(test_pid) end)
      other_char_id = register_player(other_pid)
      :ok = Session.init_timer(gid, char_id)
      assert_receive {:"$gen_cast", {:npc, {:timer_start, ^gid, 0, _pid}}}

      run =
        run_process(gid, fn ->
          :ok = Session.begin_run(gid, {:fire, other_char_id, 500})
          send(test_pid, {:run_timer, Session.get_timer(gid)})
          :ok = Session.stop_timer(gid)
        end)

      assert_receive {:run_timer, run_timer} when run_timer in 500..600
      assert_receive {:other_player, {:npc, :timer_stop}}
      assert Session.get_timer(gid) == 0, "other processes see the real timer during the run"

      finish_run(run, gid)

      assert Session.get_timer(gid) == 0
      :ok = Session.stop_timer(gid)
      assert_receive {:"$gen_cast", {:npc, :timer_stop}}
    end

    test "a timer write inside a slot run is dropped when it closes, but the fire it armed stays",
         %{char_id: char_id, gid: gid, pid: pid} do
      run =
        run_process(gid, fn ->
          :ok = Session.begin_run(gid, {:fire, char_id, 500})
          :ok = Session.set_timer(gid, 60)
        end)

      assert {_ref, _deadline, 120} = :sys.get_state(pid).armed
      finish_run(run, gid)

      assert %{timer: 0, timertick: nil, armed: {_ref, _deadline, 120}} = :sys.get_state(pid)
      assert Session.get_timer(gid) == 0
      assert_receive {:fired, "OnTimer120"}, 300
    end

    test "the NPC's own label run sees no attached player", %{char_id: char_id, gid: gid} do
      :ok = Session.init_timer(gid, char_id)
      assert_receive {:"$gen_cast", {:npc, {:timer_start, ^gid, 0, _pid}}}

      run =
        run_process(gid, fn ->
          :ok = Session.begin_run(gid, :own)
          :ok = Session.start_timer(gid)
        end)

      refute_received {:"$gen_cast", {:npc, {:timer_start, _gid, _from, _pid}}}
      assert_receive {:fired, "OnTimer50"}, 300
      finish_run(run, gid)

      :ok = Session.stop_timer(gid)
      assert_receive {:"$gen_cast", {:npc, :timer_stop}}
    end

    test "concurrent slot runs each see their own player and leave the real one",
         %{char_id: char_id, gid: gid} do
      test_pid = self()
      other_pid = spawn_link(fn -> forward_casts(test_pid) end)
      other_char_id = register_player(other_pid)
      :ok = Session.init_timer(gid, char_id)
      assert_receive {:"$gen_cast", {:npc, {:timer_start, ^gid, 0, _pid}}}

      mine = run_process(gid, fn -> :ok = Session.begin_run(gid, {:fire, char_id, 50}) end)

      theirs =
        run_process(gid, fn ->
          :ok = Session.begin_run(gid, {:fire, other_char_id, 50})
          :ok = Session.stop_timer(gid)
        end)

      assert_receive {:other_player, {:npc, :timer_stop}}
      finish_run(mine, gid)
      finish_run(theirs, gid)

      :ok = Session.stop_timer(gid)
      assert_receive {:"$gen_cast", {:npc, :timer_stop}}
      refute_received {:other_player, _message}
    end

    test "a quit run of the attached player detaches it", %{char_id: char_id, gid: gid} do
      :ok = Session.init_timer(gid, char_id)
      assert_receive {:"$gen_cast", {:npc, {:timer_start, ^gid, 0, _pid}}}

      run = run_process(gid, fn -> :ok = Session.begin_run(gid, {:quit, char_id, 50}) end)
      finish_run(run, gid)

      :ok = Session.start_timer(gid)
      refute_received {:"$gen_cast", {:npc, {:timer_start, _gid, _from, _pid}}}
      assert_receive {:fired, "OnTimer50"}, 300
    end

    test "a run whose process dies closes", %{char_id: char_id, gid: gid, pid: pid} do
      {run, ref} = spawn_monitor(fn -> :ok = Session.begin_run(gid, {:fire, char_id, 500}) end)
      assert_receive {:DOWN, ^ref, :process, ^run, :normal}

      assert_eventually(fn -> :sys.get_state(pid).runs == %{} end)
    end
  end

  defp register_player(pid) do
    char_id = System.unique_integer([:positive]) + 1_000_000_000
    state = build(:player_state, character_id: char_id)
    UnitRegistry.register_unit(:player, char_id, PlayerState, state, pid)
    on_exit(fn -> UnitRegistry.unregister_player(char_id, pid) end)
    char_id
  end

  # A label run's process: runs `fun`, then on `finish_run/1` closes its run
  # (and waits until the session has) and exits.
  defp run_process(gid, fun) do
    test_pid = self()

    pid =
      spawn_link(fn ->
        fun.()
        send(test_pid, {:run_ready, self()})

        receive do
          :finish ->
            :ok = Session.end_run(gid)
            _synced = Session.get_timer(gid)
        end
      end)

    assert_receive {:run_ready, ^pid}
    pid
  end

  defp finish_run(pid, _gid) do
    ref = Process.monitor(pid)
    send(pid, :finish)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
  end

  defp forward_casts(test_pid) do
    receive do
      {:"$gen_cast", message} ->
        send(test_pid, {:other_player, message})
        forward_casts(test_pid)
    end
  end
end
