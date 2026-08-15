defmodule Aesir.ZoneServer.Integration.WaitingRoomIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.WaitingRoomJoinRequest
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Script.Vars

  defmodule WaitingRoomNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 160, y: 150, dir: 0, sprite: 58, name: "Waiting Room"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  @room_gid 777_777

  defp npc_ctx, do: Ctx.detached(WaitingRoomNpc, @room_gid)

  test "join fills the room and warpwaitingpc warps the longest-waiting members" do
    assert %Ctx{} = Dsl.waitingroom(npc_ctx(), "Test Room", 3, "WaitingRoomNpc::OnStart", 2)

    p1 = start_player_session(position: {150, 150})
    p2 = start_player_session(position: {151, 150})
    p3 = start_player_session(position: {152, 150})

    simulate_incoming_message(p1.pid, %WaitingRoomJoinRequest{room_id: @room_gid})
    simulate_incoming_message(p2.pid, %WaitingRoomJoinRequest{room_id: @room_gid})
    assert_eventually(fn -> length(WaitingRoom.members(@room_gid)) == 2 end)

    assert {:ok, room} = WaitingRoom.get(@room_gid)
    assert WaitingRoom.fire_event?(room)

    # A third player is rejected: the owner NPC occupies one slot (limit 3 => 2).
    simulate_incoming_message(p3.pid, %WaitingRoomJoinRequest{room_id: @room_gid})
    assert_eventually(fn -> length(WaitingRoom.members(@room_gid)) == 2 end)

    assert %Ctx{} = Dsl.warpwaitingpc(npc_ctx(), "prontera", 200, 200, 2)

    assert Vars.get_server_temp("warpwaitingpc", nil) ==
             [p1.character.account_id, p2.character.account_id]

    assert 2 = Vars.get_server_temp("warpwaitingpcnum", nil)

    # Each member's warp-path cleanup removes them from the room.
    assert_eventually(fn -> WaitingRoom.members(@room_gid) == [] end)
  end

  test "enable/disable toggles the event and warping away removes a member" do
    assert %Ctx{} = Dsl.waitingroom(npc_ctx(), "W", 8, "WaitingRoomNpc::OnStart", 1)

    assert %Ctx{} = Dsl.disablewaitingroomevent(npc_ctx())
    assert {:ok, %WaitingRoom{enabled?: false}} = WaitingRoom.get(@room_gid)

    assert %Ctx{} = Dsl.enablewaitingroomevent(npc_ctx())
    assert {:ok, %WaitingRoom{enabled?: true}} = WaitingRoom.get(@room_gid)

    player = start_player_session(position: {150, 150})
    simulate_incoming_message(player.pid, %WaitingRoomJoinRequest{room_id: @room_gid})
    assert_eventually(fn -> length(WaitingRoom.members(@room_gid)) == 1 end)

    # A direct warp (not warpwaitingpc) also removes the player from the room.
    PlayerSession.warp(player.pid, "prontera", 250, 250)
    assert_eventually(fn -> WaitingRoom.members(@room_gid) == [] end)
  end
end
