defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  @moduletag :capture_log

  alias Aesir.Net.ActionRequest
  alias Aesir.Net.CardComposeRequest
  alias Aesir.Net.CardComposeResult
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.GuildSkillUpRequest
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveStop
  alias Aesir.Net.PickupItemRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Net.TradeRequest
  alias Aesir.Net.UseItem
  alias Aesir.Net.WaitingRoomCreateRequest
  alias Aesir.Net.WaitingRoomJoinRequest
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SitHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.TradeHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WaitingRoomHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  setup :verify_on_exit!

  test "routes GuildSkillUpRequest to the guild handler" do
    request = %GuildSkillUpRequest{skill_id: 10_000}

    expect(GuildHandler, :handle_skill_up_request, fn ^request, state ->
      {:noreply, state}
    end)

    assert {:noreply, %{some: :state}} = PacketHandler.handle_message(request, %{some: :state})
  end

  test "routes CardComposeRequest to card compounding" do
    request = %CardComposeRequest{card_index: 9, equipment_index: 5}

    state = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1000, inventory: %{}}
    }

    assert {:noreply, ^state} = PacketHandler.handle_message(request, state)

    assert_received {:send, :gameplay,
                     {:card_compose_result,
                      %CardComposeResult{
                        card_index: 9,
                        equipment_index: 5,
                        code: :CARD_COMPOSE_CARD_NOT_FOUND
                      }}}
  end

  test "ignores CardComposeRequest while trading" do
    request = %CardComposeRequest{card_index: 9, equipment_index: 5}

    state = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1000, inventory: %{}},
      trade: %{pid: self(), monitor: make_ref(), partner_char_id: 2000}
    }

    assert {:noreply, ^state} = PacketHandler.handle_message(request, state)
    refute_received {:send, _, _}
  end

  test "routes chat-room create and password join requests" do
    expect(WaitingRoomHandler, :create, fn s, "T", "pw", 5, false -> {:noreply, s} end)
    expect(WaitingRoomHandler, :join, fn s, 42, "pw" -> {:noreply, s} end)

    create = %WaitingRoomCreateRequest{title: "T", password: "pw", limit: 5, public: false}
    assert {:noreply, %{some: :state}} = PacketHandler.handle_message(create, %{some: :state})

    join = %WaitingRoomJoinRequest{room_id: 42, password: "pw"}
    assert {:noreply, %{some: :state}} = PacketHandler.handle_message(join, %{some: :state})
  end

  describe "room gate" do
    setup do
      state = %SessionState{
        connection_pid: self(),
        game_state: %PlayerState{character_id: 1000, x: 5, y: 6, waiting_room: 1}
      }

      %{state: state}
    end

    test "a member's move is refused with a MoveStop at their position", %{state: state} do
      reject(MovementHandler, :handle_request_move, 3)

      assert {:noreply, ^state} =
               PacketHandler.handle_message(%MoveRequest{dest_x: 50, dest_y: 50}, state)

      assert_received {:send, :gameplay, {:move_stop, %MoveStop{gid: 1000, x: 5, y: 6}}}
    end

    test "a member's item use, pickup, skill casts, and attacks are dropped", %{state: state} do
      reject(ItemHandler, :handle_use_item, 2)
      reject(SkillHandler, :handle_use_skill, 4)
      reject(SkillHandler, :handle_use_skill_ground, 5)
      reject(CombatActionHandler, :handle_attack_request, 3)
      reject(PickupHandler, :handle_pickup, 2)

      for message <- [
            %UseItem{index: 2},
            %PickupItemRequest{ground_id: 77},
            %SkillCast{skill_id: 5, level: 1, target_id: 9},
            %GroundSkillCast{skill_id: 12, level: 1, x: 7, y: 7},
            %ActionRequest{target_id: 9, action: 0},
            %ActionRequest{target_id: 9, action: 7}
          ] do
        assert {:noreply, ^state} = PacketHandler.handle_message(message, state)
      end

      refute_received {:send, _, _}
    end

    test "a member can still sit and trade", %{state: state} do
      expect(SitHandler, :handle_sit, fn s -> {:noreply, s} end)
      expect(TradeHandler, :handle_trade_request, fn s, _msg -> {:noreply, s} end)

      assert {:noreply, ^state} = PacketHandler.handle_message(%ActionRequest{action: 2}, state)
      assert {:noreply, ^state} = PacketHandler.handle_message(%TradeRequest{}, state)
    end

    test "a player outside any room moves normally", %{state: state} do
      free = put_in(state.game_state.waiting_room, nil)
      expect(MovementHandler, :handle_request_move, fn s, 50, 50 -> {:noreply, s} end)

      assert {:noreply, ^free} =
               PacketHandler.handle_message(%MoveRequest{dest_x: 50, dest_y: 50}, free)
    end
  end

  test "drops a forged server-authoritative message without touching state or the session" do
    forged = %DamageDealt{src_id: 1, target_id: 2, damage: 9_999_999}

    assert {:noreply, state} = PacketHandler.handle_message(forged, %{some: :state})
    assert state == %{some: :state}
    refute_received {:"$gen_cast", _}
    refute_received {:"$gen_call", _, _}
  end
end
