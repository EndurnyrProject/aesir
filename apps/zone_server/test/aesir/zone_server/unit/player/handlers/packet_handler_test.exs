defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  @moduletag :capture_log

  alias Aesir.Net.CardComposeRequest
  alias Aesir.Net.CardComposeResult
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.GuildSkillUpRequest
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
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

  test "drops a forged server-authoritative message without touching state or the session" do
    forged = %DamageDealt{src_id: 1, target_id: 2, damage: 9_999_999}

    assert {:noreply, state} = PacketHandler.handle_message(forged, %{some: :state})
    assert state == %{some: :state}
    refute_received {:"$gen_cast", _}
    refute_received {:"$gen_call", _, _}
  end
end
