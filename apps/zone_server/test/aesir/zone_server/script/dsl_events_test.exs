defmodule Aesir.ZoneServer.Script.DslEventsTest do
  @moduledoc """
  Covers the Task 6 event-dispatch and timer DSL ops: `donpcevent/2`
  (detached, fire-and-forget), `doevent/2` (attached-only, queues a new
  Interaction for the current player against a target NPC behind the
  calling script), and the
  self/named `initnpctimer`, `stopnpctimer`, `getnpctimer` pairs backed by
  `Npc.Session`.
  """

  use ExUnit.Case, async: false

  @moduletag :capture_log

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  defmodule TargetNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 60, y: 60, sprite: 58, name: "Target"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnStart", ctx) do
      send(:dsl_events_probe, {:fired, __MODULE__, ctx.npc_gid})
      ctx
    end
  end

  defmodule DoeventTargetNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 61, y: 61, sprite: 58, name: "DoeventTarget"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnHit", ctx) do
      send(:dsl_events_probe, {:doevent_ran, ctx.char_id, ctx.npc_gid})
      ctx
    end
  end

  defmodule SelfTimerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 62, y: 62, sprite: 58, name: "SelfTimer"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer10", ctx) do
      send(:dsl_events_probe, {:fired, __MODULE__, ctx.npc_gid})
      ctx
    end
  end

  defmodule NamedTimerNpcA do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 63, y: 63, sprite: 58, name: "Dup", unique_name: "TimerDup"}
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer10", ctx) do
      send(:dsl_events_probe, {:fired, __MODULE__, ctx.npc_gid})
      ctx
    end
  end

  defmodule NamedTimerNpcB do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 64, y: 64, sprite: 58, name: "Dup", unique_name: "TimerDup"}
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer10", ctx) do
      send(:dsl_events_probe, {:fired, __MODULE__, ctx.npc_gid})
      ctx
    end
  end

  setup do
    Aesir.TestProbe.register!(:dsl_events_probe)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    :ok
  end

  describe "donpcevent/2" do
    test "fires the target's on_event handler from a detached ctx, returns ctx unchanged" do
      NpcRegistry.reload([TargetNpc])
      ctx = Ctx.detached(TargetNpc, 1)

      assert Dsl.donpcevent(ctx, "Target::OnStart") == ctx
      assert_receive {:fired, TargetNpc, _gid}
    end

    test "an unknown ref logs a warning and no-ops" do
      NpcRegistry.reload([TargetNpc])
      ctx = Ctx.detached(TargetNpc, 1)

      log = capture_log(fn -> assert Dsl.donpcevent(ctx, "Nowhere::OnStart") == ctx end)

      assert log =~ "unknown name"
      refute_received {:fired, _module, _gid}
    end

    test "short-circuits on an already-halted ctx" do
      ctx = %{Ctx.detached(TargetNpc, 1) | status: {:error, :boom}}

      assert Dsl.donpcevent(ctx, "Target::OnStart") == ctx
      refute_received {:fired, _module, _gid}
    end
  end

  describe "doevent/2" do
    test "queues the event on the player's session, which runs it once the calling script ends" do
      NpcRegistry.reload([DoeventTargetNpc])
      {DoeventTargetNpc, placement} = hd(NpcRegistry.entries())
      target_gid = NpcRegistry.entity_id(placement)

      ctx = attached_ctx(char_id: 42)

      assert Dsl.doevent(ctx, "DoeventTarget::OnHit") == ctx
      assert_receive {:"$gen_cast", {:npc, {:queue_event, ^target_gid, "OnHit"}} = cast}
      refute_received {:doevent_ran, _char_id, _gid}

      # The calling script holds the lock: the event waits in the queue until
      # the script's process ends, then runs after the dequeue delay.
      script = spawn(fn -> Process.sleep(:infinity) end)
      ref = Process.monitor(script)

      state = %SessionState{
        game_state: ctx.game_state,
        connection_pid: self(),
        interaction_lock: {script, ref, 500}
      }

      {:noreply, state} = PlayerSession.handle_cast(cast, state)
      assert state.npc_event_queue == [{target_gid, "OnHit"}]

      Process.exit(script, :kill)
      assert_receive {:DOWN, ^ref, :process, ^script, reason}
      {:noreply, state} = PlayerSession.handle_info({:DOWN, ref, :process, script, reason}, state)
      assert_receive {:npc, {:run_queued_event, ^target_gid, "OnHit"}} = run, 500
      {:noreply, state} = PlayerSession.handle_info(run, state)

      assert_receive {:doevent_ran, 42, ^target_gid}
      assert {_pid, _ref, ^target_gid} = state.interaction_lock
    end

    test "a label the target does not declare logs a warning and no-ops" do
      NpcRegistry.reload([DoeventTargetNpc])
      ctx = attached_ctx()

      log = capture_log(fn -> assert Dsl.doevent(ctx, "DoeventTarget::OnMiss") == ctx end)

      assert log =~ "no handler"
      refute_received {:"$gen_cast", _}
    end

    test "ends the script with {:error, :no_player} on a detached ctx" do
      NpcRegistry.reload([DoeventTargetNpc])
      ctx = Ctx.detached(DoeventTargetNpc, 1)

      assert {:script_end, result} = catch_throw(Dsl.doevent(ctx, "DoeventTarget::OnHit"))

      assert result.status == {:error, :no_player}
      refute_received {:doevent_ran, _char_id, _gid}
    end

    test "fails the command and goes on in an item-script ctx (game_state set, session_pid nil)" do
      NpcRegistry.reload([DoeventTargetNpc])

      ctx =
        Ctx.from_session(
          %{game_state: %PlayerState{character_id: 1, account_id: 100}, connection_pid: self()},
          {:item, 501}
        )

      log =
        capture_log(fn ->
          result = Dsl.doevent(ctx, "DoeventTarget::OnHit")

          assert result.status == :ok
          assert result.failures == [{:doevent, :no_session}]
        end)

      assert log =~ "doevent returned failure"
      refute_received {:doevent_ran, _char_id, _gid}
    end

    test "an unknown name logs a warning and no-ops" do
      ctx = attached_ctx()

      log = capture_log(fn -> assert Dsl.doevent(ctx, "Nowhere::OnHit") == ctx end)

      assert log =~ "unknown name"
    end

    test "a malformed ref logs a warning and no-ops" do
      ctx = attached_ctx()

      log = capture_log(fn -> assert Dsl.doevent(ctx, "NoSeparator") == ctx end)

      assert log =~ "malformed ref"
    end

    test "short-circuits on an already-halted ctx" do
      ctx = %{attached_ctx() | status: {:error, :boom}}

      assert Dsl.doevent(ctx, "DoeventTarget::OnHit") == ctx
    end
  end

  describe "initnpctimer/1 and stopnpctimer/1" do
    test "arms the calling npc's own timer; stop freezes it, get reads it" do
      NpcRegistry.reload([SelfTimerNpc])
      {SelfTimerNpc, placement} = hd(NpcRegistry.entries())
      gid = NpcRegistry.entity_id(placement)
      ctx = npc_ctx(gid)

      assert Dsl.initnpctimer(ctx) == ctx
      assert_receive {:fired, SelfTimerNpc, ^gid}, 300

      assert Dsl.stopnpctimer(ctx) == ctx

      frozen = Dsl.getnpctimer(ctx)
      assert frozen >= 10
      assert Dsl.getnpctimer(ctx) == NpcSession.get_timer(gid)

      Process.sleep(20)
      assert Dsl.getnpctimer(ctx) == frozen
    end

    test "a ctx with no npc_gid logs a warning and no-ops" do
      ctx = npc_ctx(nil)

      log = capture_log(fn -> assert Dsl.initnpctimer(ctx) == ctx end)
      assert log =~ "no npc_gid"

      log = capture_log(fn -> assert Dsl.stopnpctimer(ctx) == ctx end)
      assert log =~ "no npc_gid"

      log =
        capture_log(fn ->
          assert Dsl.getnpctimer(ctx) == 0
        end)

      assert log =~ "no npc_gid"
    end

    test "short-circuits on an already-halted ctx" do
      ctx = %{npc_ctx(1) | status: {:error, :boom}}

      assert Dsl.initnpctimer(ctx) == ctx
      assert Dsl.stopnpctimer(ctx) == ctx
    end
  end

  describe "initnpctimer/2 and stopnpctimer/2" do
    test "arms every placement sharing the name" do
      NpcRegistry.reload([NamedTimerNpcA, NamedTimerNpcB])
      ctx = npc_ctx(nil)

      assert Dsl.initnpctimer(ctx, "TimerDup") == ctx

      assert_receive {:fired, NamedTimerNpcA, _gid}, 300
      assert_receive {:fired, NamedTimerNpcB, _gid}, 300
    end

    test "stops every placement sharing the name" do
      NpcRegistry.reload([NamedTimerNpcA, NamedTimerNpcB])
      ctx = npc_ctx(nil)

      Dsl.initnpctimer(ctx, "TimerDup")
      assert_receive {:fired, NamedTimerNpcA, gid_a}, 300
      assert_receive {:fired, NamedTimerNpcB, gid_b}, 300

      assert Dsl.stopnpctimer(ctx, "TimerDup") == ctx

      frozen_a = NpcSession.get_timer(gid_a)
      frozen_b = NpcSession.get_timer(gid_b)

      Process.sleep(20)
      assert NpcSession.get_timer(gid_a) == frozen_a
      assert NpcSession.get_timer(gid_b) == frozen_b
    end

    test "an unknown name logs a warning and no-ops" do
      ctx = npc_ctx(nil)

      log = capture_log(fn -> assert Dsl.initnpctimer(ctx, "Nowhere") == ctx end)
      assert log =~ "unknown name"

      log = capture_log(fn -> assert Dsl.stopnpctimer(ctx, "Nowhere") == ctx end)
      assert log =~ "unknown name"
    end

    test "short-circuits on an already-halted ctx" do
      ctx = %{npc_ctx(nil) | status: {:error, :boom}}

      assert Dsl.initnpctimer(ctx, "TimerDup") == ctx
      assert Dsl.stopnpctimer(ctx, "TimerDup") == ctx
    end
  end

  describe "getnpctimer/2" do
    test "reads the first placement's timer and warns when the name is ambiguous" do
      NpcRegistry.reload([NamedTimerNpcA, NamedTimerNpcB])

      {NamedTimerNpcA, placement_a} =
        Enum.find(NpcRegistry.entries(), &match?({NamedTimerNpcA, _}, &1))

      gid_a = NpcRegistry.entity_id(placement_a)

      ctx = npc_ctx(nil)
      Dsl.initnpctimer(ctx, "TimerDup")
      Dsl.stopnpctimer(ctx, "TimerDup")

      log =
        capture_log(fn ->
          assert Dsl.getnpctimer(ctx, "TimerDup") == NpcSession.get_timer(gid_a)
        end)

      assert log =~ "maps to 2 placements"
    end

    test "an unknown name logs a warning and returns 0" do
      ctx = npc_ctx(nil)

      log = capture_log(fn -> assert Dsl.getnpctimer(ctx, "Nowhere") == 0 end)

      assert log =~ "unknown name"
    end
  end

  defp attached_ctx(opts \\ []) do
    char_id = Keyword.get(opts, :char_id, 1)

    %Ctx{
      char_id: char_id,
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{character_id: char_id, account_id: 100},
      source: {:npc, :test_npc},
      session_pid: self(),
      npc_gid: Keyword.get(opts, :npc_gid, 500)
    }
  end

  defp npc_ctx(gid) do
    %Ctx{
      char_id: nil,
      account_id: nil,
      connection_pid: nil,
      game_state: nil,
      source: {:npc, :test_npc},
      npc_gid: gid
    }
  end
end
