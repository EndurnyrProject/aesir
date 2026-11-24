defmodule Aesir.ZoneServer.Integration.NpcSleepIntegrationTest do
  @moduledoc """
  End-to-end coverage of rAthena's `sleep` in a player dialog: the script
  detaches the player (`script_detach_rid`), so the session's interaction lock
  clears while the script sleeps, and the script resumes without a player.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Factory
  alias Aesir.Net.NpcDialog
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

  setup do
    Aesir.TestProbe.register!(:npc_sleep_integration_probe)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([SleeperNpc])
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
    simulate_incoming_message(session.pid, %NpcTalk{npc_id: NpcRegistry.entity_id(placement)})

    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
    assert_eventually(fn -> PlayerSession.get_state(session.pid).interaction_lock == nil end)
    refute_received {:resumed, _attached?}

    assert_receive {:resumed, false}, 2_000
  end
end
