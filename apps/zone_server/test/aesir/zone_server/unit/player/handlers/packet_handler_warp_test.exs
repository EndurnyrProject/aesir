defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerWarpTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.MapLoaded
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "MapLoaded after a warp respawns the player without re-syncing inventory/skills/stats" do
    game_state = %PlayerState{
      character_id: 1000,
      map_name: "geffen",
      x: 100,
      y: 120,
      pending_map_load: :warp
    }

    state = %{game_state: game_state, connection_pid: self()}

    assert {:noreply, new_state} = PacketHandler.handle_message(%MapLoaded{}, state)

    assert new_state.game_state.pending_map_load == nil
    assert_received :respawn_after_warp
    refute_received :spawn_player
    refute_received {:send, :bulk, _}
    refute_received {:send, :gameplay, _}
  end
end
