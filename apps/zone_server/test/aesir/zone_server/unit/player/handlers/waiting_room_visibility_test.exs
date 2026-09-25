defmodule Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomVisibilityTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.UnitSpawn
  alias Aesir.Net.WaitingRoomInfo
  alias Aesir.ZoneServer.Mmo.WaitingRoom
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VisibilityHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule RoomNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 152, y: 151, dir: 6, sprite: 58, name: "Room Keeper"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  describe "entered_view/2 with a player owner" do
    setup do
      owner = %WaitingRoom.Member{char_id: 2, account_id: 20, name: "Owner"}
      {:ok, room} = WaitingRoom.create_player_room(owner, "Chat", "", 5, true)
      {:ok, _} = WaitingRoom.join(room.room_id, member(3), 50, 0, "", [])

      observer = %{
        game_state: PlayerState.new(character(1)),
        connection_pid: self()
      }

      %{room_id: room.room_id, observer: observer}
    end

    test "the owner coming into view shows their room", %{room_id: room_id, observer: observer} do
      register_other(2, room_id)

      assert {:noreply, _} = VisibilityHandler.entered_view(2, observer)

      assert_received {:send, :world,
                       {:waiting_room_info,
                        %WaitingRoomInfo{room_id: ^room_id, owner_gid: 2, owner_is_npc: false}}}
    end

    test "a mere member coming into view shows nothing extra", %{
      room_id: room_id,
      observer: observer
    } do
      register_other(3, room_id)

      assert {:noreply, _} = VisibilityHandler.entered_view(3, observer)

      refute_received {:send, _, {:waiting_room_info, _}}
    end

    test "a player in no room shows nothing extra", %{observer: observer} do
      register_other(4, nil)

      assert {:noreply, _} = VisibilityHandler.entered_view(4, observer)

      refute_received {:send, _, {:waiting_room_info, _}}
    end
  end

  describe "handle_visibility_update/1 with NPCs" do
    setup do
      placement = hd(RoomNpc.spawn())
      stub(NpcRegistry, :entries, fn -> [{RoomNpc, placement}] end)
      stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
      stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
      stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
      stub(Broadcast, :to_players, fn _, _, _ -> :ok end)

      game_state = PlayerState.new(character(2001))
      UnitRegistry.register_unit(:player, 2001, PlayerState, game_state, self())

      %{gid: NpcRegistry.entity_id(placement), game_state: game_state}
    end

    test "an NPC with a room sends its spawn and its room info", %{gid: gid, game_state: gs} do
      assert :ok = WaitingRoom.create(gid, "Queue", 8, 7, "", 0, 1, 99)

      MovementHandler.handle_visibility_update(gs)

      assert_received {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid}}}

      assert_received {:"$gen_cast",
                       {:send_packet,
                        %WaitingRoomInfo{room_id: ^gid, owner_gid: ^gid, owner_is_npc: true}}}
    end

    test "an NPC without a room sends only its spawn", %{gid: gid, game_state: gs} do
      MovementHandler.handle_visibility_update(gs)

      assert_received {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid}}}
      refute_received {:"$gen_cast", {:send_packet, %WaitingRoomInfo{}}}
    end
  end

  defp member(char_id) do
    %WaitingRoom.Member{char_id: char_id, account_id: char_id * 10, name: "char#{char_id}"}
  end

  defp register_other(char_id, waiting_room) do
    game_state = %{PlayerState.new(character(char_id)) | waiting_room: waiting_room}

    UnitRegistry.register_unit(:player, char_id, PlayerState, game_state, self())
  end

  defp character(char_id) do
    %Character{
      id: char_id,
      account_id: char_id * 10,
      name: "char#{char_id}",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
