defmodule Aesir.ZoneServer.Integration.NpcScriptedWarpIntegrationTest do
  @moduledoc """
  A scripted warp must move the *session's* authoritative `PlayerState`, not
  just the read snapshot the NPC interaction carries.

  An NPC interaction runs in its own process; relocating its snapshot used to
  leave the session standing on the origin cell, so the client rendered the
  destination while the server still pathed from the origin — the player
  snapped back on its first step.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.MapMove
  alias Aesir.Net.NpcTalk
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry

  @origin {150, 150}
  @destination {160, 170}

  defmodule WarperNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, dir: 0, sprite: 58, name: "Warper"}]

    @impl true
    def on_talk(ctx), do: warp(ctx, {"prontera", 160, 170})
  end

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([WarperNpc])

    player =
      start_player_session(
        id: System.unique_integer([:positive]),
        name: "Warped",
        position: @origin
      )

    on_exit(fn -> end_player_session(player) end)

    {:ok, player: player, gid: gid_for(WarperNpc)}
  end

  test "a scripted warp relocates the session state, not just the script snapshot",
       %{player: player, gid: gid} do
    {x, y} = @origin
    assert %{map_name: "prontera", x: ^x, y: ^y} = get_player_state(player.pid)

    flush_packets()
    simulate_incoming_message(player.pid, %NpcTalk{npc_id: gid})

    {dest_x, dest_y} = @destination

    assert_receive {:packet_sent, %MapMove{map_name: "prontera", x: ^dest_x, y: ^dest_y}, _}, 500

    assert_eventually(fn ->
      match?(
        %{map_name: "prontera", x: ^dest_x, y: ^dest_y, pending_map_load: :warp},
        get_player_state(player.pid)
      )
    end)
  end

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end
end
