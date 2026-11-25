defmodule Aesir.ZoneServer.Integration.NpcSleepIntegrationTest do
  @moduledoc """
  End-to-end coverage of rAthena's `sleep` in a player dialog: the script
  detaches the player (`script_detach_rid`), so the session's interaction lock
  clears while the script sleeps, and the script resumes without a player.

  `sleep2` keeps the player attached but lets them go for the pause, as the
  reference detaches the script state while a script sleeps: the player can
  talk to another NPC meanwhile, and the waking script takes that dialog over
  until it ends.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Factory
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.NpcTalk
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  defmodule SleeperNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 170, y: 160, sprite: 58, name: "Sleeper"}]

    @impl true
    def on_talk(ctx) do
      ctx = ctx |> mes("Wait here.") |> close() |> sleep(500)
      send(:npc_sleep_integration_probe, {:resumed, Ctx.attached?(ctx)})
      ctx
    end
  end

  defmodule NapperNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 172, y: 160, sprite: 58, name: "Napper"}]

    @impl true
    def on_talk(ctx) do
      ctx = sleep2(ctx, 400)
      send(:npc_sleep_integration_probe, {:woke, self(), Ctx.attached?(ctx)})

      receive do
        :go -> ctx
      end
    end
  end

  defmodule BellNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 168, y: 160, sprite: 58, name: "Bell"}]

    @impl true
    def on_talk(ctx) do
      ctx = ctx |> mes("Ding.") |> next()
      send(:npc_sleep_integration_probe, :bell_resumed)
      ctx
    end
  end

  setup do
    Aesir.TestProbe.register!(:npc_sleep_integration_probe)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([SleeperNpc, NapperNpc, BellNpc])
    :ok
  end

  test "a sleeping script frees the player and resumes detached" do
    session =
      start_player_session(
        character: Factory.insert(:character),
        map_name: "prontera",
        position: {170, 161}
      )

    on_exit(fn -> end_player_session(session) end)
    flush_packets()

    {:ok, {SleeperNpc, placement}} = NpcRegistry.module_at("prontera", 170, 160)
    gid = NpcRegistry.entity_id(placement)
    simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid})

    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
    simulate_incoming_message(session.pid, %NpcInteract{npc_id: gid, response: {:close, true}})
    assert_eventually(fn -> PlayerSession.get_state(session.pid).interaction_lock == nil end)
    refute_received {:resumed, _attached?}

    assert_receive {:resumed, false}, 2_000
  end

  test "sleep2 lets the player go, then takes over the dialog they opened until it ends" do
    session =
      start_player_session(
        character: Factory.insert(:character),
        map_name: "prontera",
        position: {170, 161}
      )

    on_exit(fn -> end_player_session(session) end)
    flush_packets()
    bell = gid_at(168)

    simulate_incoming_message(session.pid, %NpcTalk{npc_id: gid_at(172)})
    assert_eventually(fn -> PlayerSession.get_state(session.pid).interaction_lock == nil end)

    simulate_incoming_message(session.pid, %NpcTalk{npc_id: bell})
    assert_receive {:packet_sent, %NpcDialog{npc_id: ^bell, expect: :NEXT}, _}, 1_000
    {bell_pid, _ref, ^bell} = PlayerSession.get_state(session.pid).interaction_lock

    assert_receive {:woke, napper, true}, 2_000
    state = PlayerSession.get_state(session.pid)
    assert {^napper, _ref, _gid} = state.interaction_lock
    assert [{{^bell_pid, _bell_ref, ^bell}, _flag}] = state.dialog_backups

    send(napper, :go)

    assert_eventually(fn ->
      match?({^bell_pid, _ref, ^bell}, PlayerSession.get_state(session.pid).interaction_lock)
    end)

    simulate_incoming_message(session.pid, %NpcInteract{npc_id: bell, response: {:continue, true}})

    assert_receive :bell_resumed, 1_000
  end

  defp gid_at(x) do
    {:ok, {_module, placement}} = NpcRegistry.module_at("prontera", x, 160)
    NpcRegistry.entity_id(placement)
  end
end
