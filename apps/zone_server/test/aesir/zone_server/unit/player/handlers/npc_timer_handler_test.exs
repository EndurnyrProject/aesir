defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcTimerHandlerTest do
  @moduledoc """
  Covers the player's NPC timer slot (rAthena `sd->npc_timer_id`): arming from
  the NPC's stored timer value and the one-slot rule (`npc_timerevent_start`),
  firing in schedule order with the next label armed first (`npc_timerevent`),
  running a label at once whether or not the player is in a dialog, dropping a
  slot whose NPC was reloaded, and the logout `OnTimerQuit` run
  (`npc_timerevent_quit`).
  """

  # Sync: `Npc.Registry.reload/1` writes the global `:persistent_term` registry.
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.SessionDynamicSupervisor
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcTimerHandler

  setup :set_mimic_from_context

  defmodule SlotNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 910, y: 910, dir: 0, sprite: 58, name: "SlotNpc"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer100", ctx), do: ctx
    def on_event("OnTimer250", ctx), do: ctx
    def on_event("OnTimerQuit", ctx), do: ctx
  end

  setup do
    NpcRegistry.reload([SlotNpc])
    [{SlotNpc, placement}] = NpcRegistry.entries()
    gid = NpcRegistry.entity_id(placement)
    npc_pid = NpcSession.ensure_started(gid)

    on_exit(fn ->
      DynamicSupervisor.terminate_child(SessionDynamicSupervisor, npc_pid)
      :persistent_term.erase(NpcRegistry)
    end)

    test_pid = self()

    stub(NpcEvents, :trigger_timer_attached, fn ^gid, label, ctx, session_pid, time_ms, kind ->
      send(test_pid, {:ran, label, ctx.npc_gid, session_pid, time_ms, kind})
      {:ok, spawn(fn -> :ok end)}
    end)

    {:ok, gid: gid, npc_pid: npc_pid, state: build(:session_state)}
  end

  describe "start/4" do
    test "arms the first label due after the stored timer value", %{gid: gid} = context do
      state = NpcTimerHandler.start(context.state, gid, 100, context.npc_pid)

      assert %{gid: ^gid, pending: [{250, "OnTimer250"}]} = state.npc_timer
      assert Process.read_timer(state.npc_timer.timer) in 140..150
    end

    test "is a no-op while a slot is armed, whichever NPC it is for", context do
      state = NpcTimerHandler.start(context.state, context.gid, 0, context.npc_pid)

      assert NpcTimerHandler.start(state, context.gid, 200, context.npc_pid) == state
    end

    test "arms nothing when no label is due after the stored value", context do
      assert NpcTimerHandler.start(context.state, context.gid, 250, context.npc_pid).npc_timer ==
               nil
    end
  end

  describe "fire/2" do
    test "arms the next label, then runs the fired one attached to this session at its time",
         %{gid: gid} = context do
      state = NpcTimerHandler.start(context.state, gid, 0, context.npc_pid)

      state = NpcTimerHandler.fire(state, state.npc_timer.ref)

      session_pid = self()
      assert_received {:ran, "OnTimer100", ^gid, ^session_pid, 100, :fire}
      assert %{pending: [{250, "OnTimer250"}]} = state.npc_timer
      assert Process.read_timer(state.npc_timer.timer) in 140..150
      assert {_pid, _ref, ^gid} = state.interaction_lock

      state = %{state | interaction_lock: nil}
      state = NpcTimerHandler.fire(state, state.npc_timer.ref)

      assert_received {:ran, "OnTimer250", ^gid, _session_pid, 250, :fire}
      assert state.npc_timer == nil
    end

    test "runs the label beside an open dialog without taking the dialog lock", context do
      lock = {spawn(fn -> :ok end), make_ref(), 0x5000_0001}
      state = %{context.state | interaction_lock: lock}
      state = NpcTimerHandler.start(state, context.gid, 0, context.npc_pid)

      state = NpcTimerHandler.fire(state, state.npc_timer.ref)

      assert_received {:ran, "OnTimer100", _gid, _session_pid, 100, :fire}
      assert state.interaction_lock == lock
    end

    test "ignores a stale ref", context do
      state = NpcTimerHandler.start(context.state, context.gid, 0, context.npc_pid)

      assert NpcTimerHandler.fire(state, make_ref()) == state
      refute_received {:ran, _, _, _, _, _}
    end

    test "drops the label of a slot whose NPC session was replaced", context do
      stale_npc_pid = spawn(fn -> :ok end)
      state = NpcTimerHandler.start(context.state, context.gid, 0, stale_npc_pid)

      NpcTimerHandler.fire(state, state.npc_timer.ref)

      refute_received {:ran, _, _, _, _, _}
    end
  end

  describe "stop/1" do
    test "cancels the armed slot", context do
      state = NpcTimerHandler.start(context.state, context.gid, 0, context.npc_pid)
      timer = state.npc_timer.timer

      assert NpcTimerHandler.stop(state).npc_timer == nil
      assert Process.read_timer(timer) == false
    end
  end

  describe "quit/1" do
    test "drops the slot and runs OnTimerQuit at the armed label's time", %{gid: gid} = context do
      state = NpcTimerHandler.start(context.state, gid, 0, context.npc_pid)

      assert {%{npc_timer: nil}, pid} = NpcTimerHandler.quit(state)

      assert is_pid(pid)
      assert_received {:ran, "OnTimerQuit", ^gid, _session_pid, 100, :quit}
    end

    test "runs nothing without a slot", context do
      assert {state, nil} = NpcTimerHandler.quit(context.state)
      assert state == context.state
      refute_received {:ran, _, _, _, _, _}
    end
  end
end
