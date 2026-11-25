defmodule Aesir.ZoneServer.NpcAttachedTimerIntegrationTest do
  @moduledoc """
  End-to-end coverage for player-attached NPC timers (rAthena `initnpctimer
  "<npc>",1`), through the real touch, dialog and session paths:

  1. Touching the NPC attaches the player and opens a dialog; while the player
     leaves it unanswered, the `OnTimer` label fires attached to the player
     and warps them, as `jupe_goto#1` and `gate#start` do.
  2. A player logging out with an armed slot runs the NPC's `OnTimerQuit`
     label attached to them, and its player commands still reach the session.
  3. A label firing while the player is in another NPC's dialog takes the
     player over (rAthena `script_attach_state`): the open dialog comes back
     when the label ends, and is lost when the label waits for the player.
     While the open dialog's script runs between two waits, the label starts
     only once it waits.
  4. The label's view of the NPC timer lasts until its first wait: before it,
     `getnpctimer` reads the slot's time, after it the NPC's own timer.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.MoveRequest
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.NpcTalk
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Warps

  defmodule TalkerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 118, y: 60, sprite: 58, name: "Talker", unique_name: "Talker#stack"}
      ]

    @impl true
    def on_talk(ctx) do
      ctx = ctx |> initnpctimer("Clock#stack", 1) |> mes("first") |> next()
      send(:npc_attached_timer_probe, :talker_resumed)
      ctx
    end
  end

  defmodule SlowTalkerNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 118, y: 60, sprite: 58, name: "Talker", unique_name: "Talker#stack"}
      ]

    @impl true
    def on_talk(ctx) do
      ctx = initnpctimer(ctx, "Clock#stack", 1)
      send(:npc_attached_timer_probe, :talker_running)
      Process.sleep(900)
      ctx = ctx |> mes("first") |> next()
      send(:npc_attached_timer_probe, :talker_resumed)
      ctx
    end
  end

  defmodule ReaderNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 118, y: 60, sprite: 58, name: "Reader", unique_name: "Reader#stack"}
      ]

    @impl true
    def on_talk(ctx), do: initnpctimer(ctx, "Reader#stack", 1)

    @impl true
    def on_event("OnTimer300", ctx) do
      send(:npc_attached_timer_probe, {:before_wait, getnpctimer(ctx)})
      ctx = ctx |> mes("read") |> next()
      send(:npc_attached_timer_probe, {:after_wait, getnpctimer(ctx)})
      ctx
    end
  end

  defmodule QuietClockNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 130, y: 70, sprite: 58, name: "Clock", unique_name: "Clock#stack"}
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer500", ctx) do
      send(:npc_attached_timer_probe, :clock_ran)
      ctx
    end
  end

  defmodule TalkingClockNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 130, y: 70, sprite: 58, name: "Clock", unique_name: "Clock#stack"}
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer500", ctx) do
      send(:npc_attached_timer_probe, :clock_waiting)
      ctx = ctx |> mes("tick") |> next()
      send(:npc_attached_timer_probe, :clock_answered)
      ctx
    end
  end

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

  describe "a label firing over another NPC's open dialog" do
    test "takes the player and gives the dialog back when it ends" do
      NpcRegistry.reload([TalkerNpc, QuietClockNpc])
      {player, talker_gid} = open_talker_dialog()
      {talker_pid, _ref, ^talker_gid} = :sys.get_state(player.pid).interaction_lock

      assert_receive :clock_ran, 1_000

      assert_eventually(fn ->
        match?(
          %{interaction_lock: {^talker_pid, _ref, ^talker_gid}, dialog_backups: []},
          :sys.get_state(player.pid)
        )
      end)

      answer(player, talker_gid)
      assert_receive :talker_resumed, 1_000
    end

    test "loses the dialog for good once the label waits for the player" do
      NpcRegistry.reload([TalkerNpc, TalkingClockNpc])
      clock_gid = gid_for(TalkingClockNpc)
      {player, talker_gid} = open_talker_dialog()
      {talker_pid, _ref, ^talker_gid} = :sys.get_state(player.pid).interaction_lock
      talker_ref = Process.monitor(talker_pid)

      assert_receive :clock_waiting, 1_000

      assert Enum.any?(
               collect_packets_of_type(NpcDialog),
               &match?(%{npc_id: ^clock_gid, text: "tick"}, &1)
             )

      assert_receive {:DOWN, ^talker_ref, :process, ^talker_pid, _reason}, 1_000

      state = :sys.get_state(player.pid)
      assert {_clock_pid, _ref, ^clock_gid} = state.interaction_lock
      assert state.dialog_backups == []

      answer(player, talker_gid)
      answer(player, clock_gid)
      assert_receive :clock_answered, 1_000
      assert_eventually(fn -> :sys.get_state(player.pid).interaction_lock == nil end)
      refute_received :talker_resumed
    end
  end

  test "a label firing while the open dialog's script runs starts once that script waits" do
    NpcRegistry.reload([SlowTalkerNpc, QuietClockNpc])
    player = start_listener()
    talker_gid = gid_for(SlowTalkerNpc)
    simulate_incoming_message(player.pid, %NpcTalk{npc_id: talker_gid})

    assert_receive :talker_running, 1_000
    refute_receive :clock_ran, 700

    assert_receive :clock_ran, 1_000
    assert Enum.any?(collect_packets_of_type(NpcDialog), &match?(%{npc_id: ^talker_gid}, &1))

    assert_eventually(fn ->
      match?(%{interaction_lock: {_pid, _ref, ^talker_gid}}, :sys.get_state(player.pid))
    end)

    answer(player, talker_gid)
    assert_receive :talker_resumed, 1_000
  end

  test "a label reads the slot's time until its first wait, then the NPC's own timer" do
    NpcRegistry.reload([ReaderNpc])
    player = start_listener()
    reader_gid = gid_for(ReaderNpc)
    simulate_incoming_message(player.pid, %NpcTalk{npc_id: reader_gid})

    assert_receive {:before_wait, before}, 1_000
    assert before in 300..400
    assert Enum.any?(collect_packets_of_type(NpcDialog), &match?(%{npc_id: ^reader_gid}, &1))

    answer(player, reader_gid)
    assert_receive {:after_wait, 0}, 1_000
  end

  defp start_listener do
    player =
      start_player_session(
        id: System.unique_integer([:positive]),
        name: "Listener",
        position: {117, 60}
      )

    on_exit(fn -> end_player_session(player) end)
    player
  end

  defp open_talker_dialog do
    player = start_listener()
    talker_gid = gid_for(TalkerNpc)
    simulate_incoming_message(player.pid, %NpcTalk{npc_id: talker_gid})

    assert Enum.any?(
             collect_packets_of_type(NpcDialog),
             &match?(%{npc_id: ^talker_gid, text: "first"}, &1)
           )

    {player, talker_gid}
  end

  defp answer(player, gid),
    do:
      simulate_incoming_message(player.pid, %NpcInteract{npc_id: gid, response: {:continue, true}})

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end
end
