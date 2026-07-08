defmodule Aesir.ZoneServer.Npc.EventsTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import ExUnit.CaptureLog

  alias Aesir.Net.NpcDialog
  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule NamedNpcA do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 10, y: 10, sprite: 58, name: "Dup", unique_name: "Dup#pt"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnStart", ctx) do
      send(:events_test_probe, {:fired, __MODULE__, ctx.npc_gid})
      ctx
    end
  end

  defmodule NamedNpcB do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 20, y: 20, sprite: 58, name: "Dup", unique_name: "Dup#pt"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnStart", ctx) do
      send(:events_test_probe, {:fired, __MODULE__, ctx.npc_gid})
      ctx
    end
  end

  defmodule OtherNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 30, y: 30, sprite: 58, name: "Other"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnOther", ctx) do
      send(:events_test_probe, {:fired, __MODULE__, ctx.npc_gid})
      ctx
    end
  end

  defmodule CrashingNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 40, y: 40, sprite: 58, name: "Crash"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnCrash", _ctx), do: raise("boom")
  end

  defmodule ExitingNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 45, y: 45, sprite: 58, name: "Exit"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnExit", _ctx), do: exit(:boom)
  end

  defmodule DialogNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 50, y: 50, sprite: 58, name: "Dialog"}]

    @impl true
    def on_talk(ctx), do: ctx |> mes("talk") |> close()

    @impl true
    def on_event("OnTouch", ctx), do: ctx |> mes("touched") |> close()
  end

  setup do
    Process.register(self(), :events_test_probe)
    on_exit(fn -> :persistent_term.erase(Registry) end)
    :ok
  end

  describe "trigger/1" do
    test "fires on_event once per placement sharing the name" do
      Registry.reload([NamedNpcA, NamedNpcB])

      assert :ok = Events.trigger("Dup#pt::OnStart")

      assert_receive {:fired, NamedNpcA, _gid}
      assert_receive {:fired, NamedNpcB, _gid}
    end

    test "logs a warning and returns :ok for an unknown name" do
      Registry.reload([NamedNpcA])

      log = capture_log(fn -> assert :ok = Events.trigger("Nonexistent::OnStart") end)

      assert log =~ "unknown name"
      refute_received {:fired, _module, _gid}
    end

    test "logs a warning and returns :ok when the label isn't declared" do
      Registry.reload([NamedNpcA])

      log = capture_log(fn -> assert :ok = Events.trigger("Dup#pt::OnMissing") end)

      assert log =~ "no handler"
      refute_received {:fired, _module, _gid}
    end

    test "logs a warning and returns :ok for a malformed ref" do
      log = capture_log(fn -> assert :ok = Events.trigger("NoSeparator") end)

      assert log =~ "malformed ref"
    end
  end

  describe "trigger_all/1" do
    test "hits every module declaring the label, skips others" do
      Registry.reload([NamedNpcA, OtherNpc])

      assert :ok = Events.trigger_all("OnStart")

      assert_receive {:fired, NamedNpcA, _gid}
      refute_received {:fired, OtherNpc, _gid}
    end
  end

  describe "trigger_attached/4" do
    test "starts an interaction entering on_event, suspends on dialog" do
      Registry.reload([DialogNpc])
      {DialogNpc, placement} = hd(Registry.entries())
      gid = Registry.entity_id(placement)

      {:ok, pid} = Events.trigger_attached(gid, "OnTouch", base_ctx(gid), self())
      ref = Process.monitor(pid)

      assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: "touched"}}}
      assert_receive {:DOWN, ^ref, :process, ^pid, reason}
      assert reason in [:normal, :noproc]
    end

    test "returns {:error, :no_handler} when the label isn't declared" do
      Registry.reload([DialogNpc])
      {DialogNpc, placement} = hd(Registry.entries())
      gid = Registry.entity_id(placement)

      assert {:error, :no_handler} =
               Events.trigger_attached(gid, "OnUndeclared", base_ctx(gid), self())
    end

    test "returns {:error, :no_handler} for an unresolved gid" do
      assert {:error, :no_handler} =
               Events.trigger_attached(0x5000_0000 - 1, "OnTouch", base_ctx(0), self())
    end
  end

  describe "crash isolation" do
    test "a raising detached handler crashes only its own task" do
      Registry.reload([CrashingNpc, NamedNpcA])

      assert :ok = Events.trigger("Crash::OnCrash")
      assert :ok = Events.trigger("Dup#pt::OnStart")

      assert_receive {:fired, NamedNpcA, _gid}
    end

    test "an exiting detached handler logs the crash and only takes down its own task" do
      Registry.reload([ExitingNpc, NamedNpcA])

      log =
        capture_log(fn ->
          assert :ok = Events.trigger("Exit::OnExit")
          Process.sleep(50)
        end)

      assert log =~ "npc event crashed"
      assert log =~ "OnExit"
      assert log =~ ":boom"

      assert :ok = Events.trigger("Dup#pt::OnStart")
      assert_receive {:fired, NamedNpcA, _gid}
    end
  end

  defp base_ctx(gid) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1, account_id: 100},
      source: {:npc, :test_npc},
      npc_gid: gid
    }
  end
end
