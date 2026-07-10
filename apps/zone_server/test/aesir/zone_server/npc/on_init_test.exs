defmodule Aesir.ZoneServer.Npc.OnInitTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Npc.Registry

  defmodule InitNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 10, y: 10, sprite: 58, name: "InitA"},
        %{map: "prontera", x: 20, y: 20, sprite: 58, name: "InitB"}
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnInit", ctx) do
      send(:on_init_test_probe, {:initialized, ctx.npc_gid})
      ctx
    end
  end

  defmodule OtherNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 30, y: 30, sprite: 58, name: "Other"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnOther", ctx), do: ctx
  end

  defmodule CrashingInitNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 40, y: 40, sprite: 58, name: "CrashInit"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnInit", _ctx), do: raise("boom")
  end

  defmodule SleepyInitNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 50, y: 50, sprite: 58, name: "Sleepy"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnInit", ctx) do
      Process.sleep(:infinity)
      ctx
    end
  end

  setup do
    Process.register(self(), :on_init_test_probe)
    on_exit(fn -> :persistent_term.erase(Registry) end)
    :ok
  end

  test "runs OnInit exactly once per placement, each with its own gid" do
    Registry.reload([InitNpc])
    [{InitNpc, placement_a}, {InitNpc, placement_b}] = Registry.entries()
    gid_a = Registry.entity_id(placement_a)
    gid_b = Registry.entity_id(placement_b)

    assert :ok = Events.run_on_init()

    assert_receive {:initialized, ^gid_a}
    assert_receive {:initialized, ^gid_b}
    refute_receive {:initialized, _other_gid}
  end

  test "does not fire OnInit on modules that don't declare it" do
    Registry.reload([OtherNpc])

    assert :ok = Events.run_on_init()

    refute_receive {:initialized, _gid}
  end

  test "a raising OnInit is logged and does not block other NPCs' OnInit" do
    Registry.reload([CrashingInitNpc, InitNpc])

    [gid_a, gid_b] =
      Registry.entries()
      |> Enum.filter(fn {module, _placement} -> module == InitNpc end)
      |> Enum.map(fn {_module, placement} -> Registry.entity_id(placement) end)

    log =
      capture_log(fn ->
        assert :ok = Events.run_on_init()
      end)

    assert log =~ "npc event crashed"
    assert log =~ "boom"

    assert_receive {:initialized, ^gid_a}
    assert_receive {:initialized, ^gid_b}
  end

  test "a straggler past the timeout is logged and abandoned, run_on_init returns promptly" do
    Registry.reload([SleepyInitNpc])

    {elapsed_us, log} =
      :timer.tc(fn ->
        capture_log(fn -> assert :ok = Events.run_on_init(timeout: 50) end)
      end)

    assert log =~ "did not finish"
    assert elapsed_us < 1_000_000
  end
end
