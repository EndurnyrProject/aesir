defmodule Aesir.ZoneServer.NpcAttachedTimerIntegrationTest do
  @moduledoc """
  End-to-end coverage for player-attached NPC timers (rAthena `initnpctimer
  "<npc>",1`), through the real touch, dialog and session paths:

  1. Touching the NPC attaches the player and opens a dialog; while the player
     leaves it unanswered, the `OnTimer` label fires attached to the player
     and warps them, as `jupe_goto#1` and `gate#start` do.
  2. A player logging out with an armed slot runs the NPC's `OnTimerQuit`
     label attached to them, and its player commands still reach the session.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.MoveRequest
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Warps

  defmodule PortalNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{
          map: "prontera",
          x: 120,
          y: 60,
          sprite: 45,
          name: "Portal",
          unique_name: "Portal#attached",
          trigger: {1, 1}
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouch_", ctx) do
      ctx
      |> initnpctimer("Portal#attached", 1)
      |> mes("This light...")
      |> next()
    end

    def on_event("OnTimer100", ctx) do
      send(:npc_attached_timer_probe, {:timer_ran, ctx.char_id})
      ctx |> stopnpctimer() |> warp("prontera", 150, 150)
    end

    def on_event("OnTimerQuit", ctx) do
      ctx = set_char_var(ctx, :timer_quit_seen, 1)
      send(:npc_attached_timer_probe, {:quit_ran, ctx.char_id, ctx.failures})
      ctx
    end
  end

  defmodule SlowPortalNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{
          map: "prontera",
          x: 120,
          y: 60,
          sprite: 45,
          name: "SlowPortal",
          unique_name: "SlowPortal#attached",
          trigger: {1, 1}
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouch_", ctx), do: initnpctimer(ctx, "SlowPortal#attached", 1)

    def on_event("OnTimer60000", ctx), do: ctx

    def on_event("OnTimerQuit", ctx) do
      ctx = set_char_var(ctx, :timer_quit_seen, 1)
      send(:npc_attached_timer_probe, {:quit_ran, ctx.char_id, ctx.failures})
      ctx
    end
  end

  setup do
    Aesir.TestProbe.register!(:npc_attached_timer_probe)
    stub(Warps, :for_map, fn _ -> :error end)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    :ok
  end

  defp touch_portal do
    player =
      start_player_session(
        id: System.unique_integer([:positive]),
        name: "Visitor",
        position: {117, 60}
      )

    simulate_incoming_message(player.pid, %MoveRequest{dest_x: 121, dest_y: 60})
    player
  end

  test "the attached timer warps a player who leaves the portal dialog unanswered" do
    NpcRegistry.reload([PortalNpc])
    player = touch_portal()
    on_exit(fn -> end_player_session(player) end)
    char_id = player.character.id

    assert_eventually(fn -> :sys.get_state(player.pid).interaction_lock != nil end)

    assert_receive {:timer_ran, ^char_id}, 1_000

    assert_eventually(fn ->
      match?(%{map_name: "prontera", x: 150, y: 150}, get_player_state(player.pid))
    end)

    assert :sys.get_state(player.pid).npc_timer == nil
  end

  test "logging out with an armed slot runs OnTimerQuit attached to the player" do
    NpcRegistry.reload([SlowPortalNpc])
    player = touch_portal()
    char_id = player.character.id

    assert_eventually(fn -> :sys.get_state(player.pid).npc_timer != nil end)

    end_player_session(player)

    assert_receive {:quit_ran, ^char_id, []}, 1_000
  end
end
