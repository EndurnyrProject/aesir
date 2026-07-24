defmodule Aesir.ZoneServer.Integration.AnnouncementIntegrationTest do
  @moduledoc """
  End-to-end broadcast delivery against the real subsystems (design "Testing"
  item 4, architecture section 8). Each scope drives the real
  `Aesir.ZoneServer.Announcement` fan-out over a live `SpatialIndex` and real
  `PlayerSession`s; the global case additionally exercises the
  `InterServer.PubSub` -> `Map.Coordinator` -> `deliver_local` path across two
  maps.

  Every player is started with its own tagged connection process that forwards
  each outbound push to the test as `{:got, char_id, struct}`, so a scope's
  "who received it" can be asserted per player rather than in aggregate.
  """

  use Aesir.ZoneServer.IntegrationCase

  import Bitwise

  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  @moduletag :capture_log

  @map_a "prontera"
  @map_b "geffen"

  describe "self scope" do
    test "only the triggering player receives the announcement" do
      caller = spawn_player(6001, @map_a, {150, 150})
      _bystander = spawn_player(6002, @map_a, {150, 150})
      flush_announcements()

      ctx = ctx_for(caller)
      {:ok, bc_self} = Flags.value("bc_self")

      Dsl.announce(ctx, "for your eyes only", bc_self)

      assert_receive {:got, 6001, %AnnouncementMsg{text: "for your eyes only", style: :LOCAL}},
                     500

      refute_receive {:got, 6002, %AnnouncementMsg{}}, 150
    end
  end

  describe "map scope" do
    test "every player on the map receives it; a player on another map does not" do
      here_1 = spawn_player(6101, @map_a, {150, 150})
      _here_2 = spawn_player(6102, @map_a, {30, 30})
      _elsewhere = spawn_player(6103, @map_b, {150, 150})
      flush_announcements()

      ctx = ctx_for(here_1)
      {:ok, bc_map} = Flags.value("bc_map")

      Dsl.mapannounce(ctx, @map_a, "map wide notice", bc_map)

      assert_receive {:got, 6101, %AnnouncementMsg{text: "map wide notice", style: :CENTER}}, 500
      assert_receive {:got, 6102, %AnnouncementMsg{text: "map wide notice"}}, 500
      refute_receive {:got, 6103, %AnnouncementMsg{}}, 150
    end
  end

  describe "area scope" do
    test "only a player inside the rectangle receives it" do
      inside = spawn_player(6201, @map_a, {150, 150})
      _outside = spawn_player(6202, @map_a, {30, 30})
      flush_announcements()

      ctx = ctx_for(inside)
      {:ok, bc_area} = Flags.value("bc_area")

      Dsl.areaannounce(ctx, @map_a, 140, 140, 160, 160, "step closer", bc_area)

      assert_receive {:got, 6201, %AnnouncementMsg{text: "step closer", style: :CENTER}}, 500
      refute_receive {:got, 6202, %AnnouncementMsg{}}, 150
    end
  end

  describe "global scope" do
    setup do
      # Push the coordinators' first broadcast tick past the test window so no
      # lazy mob spawning runs while we drive the fan-out.
      prev = Application.get_env(:zone_server, :idle_broadcast_interval_ms)
      Application.put_env(:zone_server, :idle_broadcast_interval_ms, 60_000)

      on_exit(fn ->
        case prev do
          nil -> Application.delete_env(:zone_server, :idle_broadcast_interval_ms)
          value -> Application.put_env(:zone_server, :idle_broadcast_interval_ms, value)
        end
      end)

      :ok
    end

    test "to_all reaches players on different maps via the coordinator fan-out" do
      ensure_coordinator(@map_a)
      ensure_coordinator(@map_b)

      _on_a = spawn_player(6301, @map_a, {150, 150})
      _on_b = spawn_player(6302, @map_b, {150, 150})
      flush_announcements()

      flag = bor(elem(Flags.value("bc_all"), 1), elem(Flags.value("bc_blue"), 1))
      %{scope: scope, color: color} = Flags.decode(flag, 0)

      Announcement.to_all(%{
        text: "server maintenance soon",
        color: color,
        style: Flags.style_for(scope),
        source_name: ""
      })

      assert_receive {:got, 6301,
                      %AnnouncementMsg{
                        text: "server maintenance soon",
                        style: :TOP,
                        color: 0x0099FF
                      }},
                     500

      assert_receive {:got, 6302,
                      %AnnouncementMsg{text: "server maintenance soon", color: 0x0099FF}},
                     500
    end
  end

  describe "npc-anchored area scope (bc_area ||| bc_npc)" do
    test "the rectangle is centered on the NPC's cell, not the acting player's" do
      # Acting player stands far from the NPC; a witness stands next to the NPC.
      # With bc_npc the rectangle centers on the NPC, so the witness receives it
      # and the acting player (outside the NPC rectangle) does not. Anchoring on
      # the player instead would invert both results.
      npc_gid = 0x5000_9999
      npc_placement = %Placement{map: @map_a, x: 150, y: 150, sprite: 58, name: "Crier"}

      stub(NpcRegistry, :module_for_unit, fn ^npc_gid -> {:ok, {__MODULE__, npc_placement}} end)

      acting = spawn_player(6401, @map_a, {30, 30})
      _witness = spawn_player(6402, @map_a, {155, 155})
      flush_announcements()

      ctx = %{ctx_for(acting) | npc_gid: npc_gid}
      flag = bor(elem(Flags.value("bc_area"), 1), elem(Flags.value("bc_npc"), 1))

      Dsl.announce(ctx, "gather round", flag)

      assert_receive {:got, 6402, %AnnouncementMsg{text: "gather round", style: :CENTER}}, 500
      refute_receive {:got, 6401, %AnnouncementMsg{}}, 150
    end
  end

  # --- helpers ---------------------------------------------------------------

  defp spawn_player(char_id, map, {x, y}) do
    test_pid = self()
    conn = spawn_link(fn -> tagged_connection_loop(test_pid, char_id) end)

    session =
      start_player_session(
        id: char_id,
        name: "Ann#{char_id}",
        map_name: map,
        position: {x, y},
        connection_pid: conn
      )

    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp tagged_connection_loop(test_pid, char_id) do
    receive do
      {:send, _channel, {_tag, proto}} ->
        send(test_pid, {:got, char_id, proto})
        tagged_connection_loop(test_pid, char_id)

      _ ->
        tagged_connection_loop(test_pid, char_id)
    end
  end

  defp ctx_for(%{pid: pid, connection_pid: conn}) do
    game_state = get_player_state(pid)
    Ctx.from_session(%{game_state: game_state, connection_pid: conn}, {:npc, :test})
  end

  defp ensure_coordinator(map) do
    case Registry.lookup(Aesir.ZoneServer.MapRegistry, map) do
      [{pid, _}] ->
        pid

      [] ->
        {:ok, pid} = Coordinator.start_link(map_name: map)
        on_exit(fn -> stop_if_alive(pid) end)
        pid
    end
  end

  defp stop_if_alive(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  end

  defp flush_announcements do
    receive do
      {:got, _id, %AnnouncementMsg{}} -> flush_announcements()
      {:got, _id, _other} -> flush_announcements()
    after
      50 -> :ok
    end
  end
end
