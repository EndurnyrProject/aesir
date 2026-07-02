defmodule Aesir.ZoneServer.Script.InteractionTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @gid 0x5000_0042
  @supervisor Aesir.ZoneServer.Npc.InteractionSupervisor

  defmodule CloseNpc do
    use Aesir.ZoneServer.Npc, spawn: []

    @impl true
    def on_talk(ctx), do: ctx |> mes("bye") |> close()
  end

  defmodule NextThenSelectNpc do
    use Aesir.ZoneServer.Npc, spawn: []

    @impl true
    def on_talk(ctx) do
      ctx = ctx |> mes("hi") |> next()
      {ctx, choice} = select(ctx, ["A", "B"])
      send(:interaction_test_probe, {:chose, choice})
      close(ctx)
    end
  end

  defmodule AutoCloseNpc do
    use Aesir.ZoneServer.Npc, spawn: []

    # Returns with un-flushed page text and no terminal op.
    @impl true
    def on_talk(ctx), do: mes(ctx, "dangling")
  end

  defmodule HangNpc do
    use Aesir.ZoneServer.Npc, spawn: []

    @impl true
    def on_talk(ctx), do: next(ctx)
  end

  defmodule CrashNpc do
    use Aesir.ZoneServer.Npc, spawn: []

    @impl true
    def on_talk(_ctx), do: raise("boom")
  end

  defmodule TodoNpc do
    use Aesir.ZoneServer.Npc, spawn: []

    @impl true
    def on_talk(ctx) do
      ctx = ctx |> mes("hi") |> next()
      todo(ctx, :getpartymember, [0])
    end
  end

  setup do
    Process.register(self(), :interaction_test_probe)
    :ok
  end

  test "runs on_talk straight-line, flushes CLOSE, exits :normal" do
    {:ok, pid} = start_interaction(CloseNpc)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: "bye"}}}
    assert_clean_exit(ref, pid)
  end

  test "runs under the InteractionSupervisor" do
    {:ok, pid} = start_interaction(HangNpc)

    assert pid in (@supervisor |> Task.Supervisor.children())
  end

  test "blocks on next/select and resumes from routed NpcInteract" do
    {:ok, pid} = start_interaction(NextThenSelectNpc)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT, text: "hi"}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: ["A", "B"]}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:choice, 2}}})

    assert_receive {:chose, 2}
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE}}}
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 500
  end

  test "auto-flushes a CLOSE for un-flushed page on normal return" do
    {:ok, pid} = start_interaction(AutoCloseNpc)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: "dangling"}}}
    assert_clean_exit(ref, pid)
  end

  test "session death terminates the interaction (monitor, no link)" do
    session =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, pid} = Interaction.start(session, HangNpc, base_ctx())
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(session, :stop)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
  end

  test "idle timeout reaps an abandoned interaction" do
    prev = Application.get_env(:zone_server, :dialog_idle_timeout)
    Application.put_env(:zone_server, :dialog_idle_timeout, 50)
    on_exit(fn -> restore_idle_timeout(prev) end)

    {:ok, pid} = start_interaction(HangNpc)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
  end

  test "a todo stub raise ends the interaction without killing the session" do
    session = spawn(fn -> Process.sleep(:infinity) end)
    session_ref = Process.monitor(session)

    {:ok, pid} = Interaction.start(session, TodoNpc, base_ctx())
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT, text: "hi"}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: @gid, response: {:continue, true}}})

    assert_receive {:DOWN, ^ref, :process, ^pid,
                    {%Aesir.ZoneServer.Script.NotImplementedError{buildin: :getpartymember}, _}},
                   500

    assert Process.alive?(session)
    refute_receive {:DOWN, ^session_ref, :process, ^session, _}, 100
  end

  test "an interaction crash does not kill the spawning session (no link)" do
    session = spawn(fn -> Process.sleep(:infinity) end)
    session_ref = Process.monitor(session)

    {:ok, pid} = Interaction.start(session, CrashNpc, base_ctx())
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, _crash_reason}, 500
    refute_receive {:DOWN, ^session_ref, :process, ^session, _}, 200
    assert Process.alive?(session)
  end

  # A fire-and-finish interaction may exit before the monitor is installed, in
  # which case the :DOWN reason is :noproc rather than :normal; both mean the
  # process terminated cleanly (no crash).
  defp assert_clean_exit(ref, pid) do
    assert_receive {:DOWN, ^ref, :process, ^pid, reason}, 500
    assert reason in [:normal, :noproc]
  end

  defp start_interaction(module), do: Interaction.start(self(), module, base_ctx())

  defp base_ctx(conn \\ self()) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: conn,
      game_state: %PlayerState{character_id: 1, account_id: 100},
      source: {:npc, :test_npc},
      npc_gid: @gid
    }
  end

  defp restore_idle_timeout(nil), do: Application.delete_env(:zone_server, :dialog_idle_timeout)
  defp restore_idle_timeout(v), do: Application.put_env(:zone_server, :dialog_idle_timeout, v)
end
