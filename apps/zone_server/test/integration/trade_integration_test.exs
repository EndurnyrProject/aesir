defmodule Aesir.ZoneServer.Integration.TradeIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Net.MoveRequest
  alias Aesir.Net.TradeCancelled
  alias Aesir.Net.TradeOpened
  alias Aesir.Net.TradeRequest
  alias Aesir.Net.TradeRequestReceived
  alias Aesir.Net.TradeResponse
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Trade.Supervisor, as: TradeSupervisor

  test "request and accept opens one trade for both players" do
    requester = player("TradeReq", {150, 150})
    target = player("TradeTarget", {151, 150})

    request(requester, target)

    assert_receive {:packet_sent,
                    %TradeRequestReceived{
                      char_id: requester_id,
                      name: "TradeReq"
                    }, _},
                   1_000

    assert requester_id == requester.character.id

    simulate_incoming_message(target.pid, %TradeResponse{accept: true})

    requester_id = requester.character.id
    target_id = target.character.id

    assert_receive {:packet_sent,
                    %TradeOpened{partner_char_id: ^target_id, partner_name: "TradeTarget"}, _},
                   1_000

    assert_receive {:packet_sent,
                    %TradeOpened{partner_char_id: ^requester_id, partner_name: "TradeReq"}, _},
                   1_000

    assert_eventually(fn ->
      requester_state = PlayerSession.get_state(requester.pid)
      target_state = PlayerSession.get_state(target.pid)

      requester_state.game_state.action_state == :trading and
        target_state.game_state.action_state == :trading and
        is_pid(requester_state.trade.pid) and
        requester_state.trade.pid == target_state.trade.pid and
        is_reference(requester_state.trade.monitor) and
        is_reference(target_state.trade.monitor)
    end)

    trade_pid = PlayerSession.get_state(requester.pid).trade.pid
    assert Process.alive?(trade_pid)

    assert Enum.any?(
             DynamicSupervisor.which_children(Process.get({TradeSupervisor, :server})),
             fn {_id, pid, _type, _modules} -> pid == trade_pid end
           )
  end

  test "declining clears the pending request and notifies the requester" do
    requester = player("DeclineReq", {150, 150})
    target = player("DeclineTarget", {151, 150})

    request(requester, target)
    assert_receive {:packet_sent, %TradeRequestReceived{}, _}, 1_000

    simulate_incoming_message(target.pid, %TradeResponse{accept: false})

    assert_receive {:packet_sent, %TradeCancelled{reason: :TRADE_CANCEL_REASON_DECLINED}, _},
                   1_000

    assert PlayerSession.get_state(requester.pid).trade == nil
    assert PlayerSession.get_state(target.pid).pending_trade_invite == nil
  end

  test "expiry clears the request and a stale expiry after accept is harmless" do
    requester = player("ExpireReq", {150, 150})
    target = player("ExpireTarget", {151, 150})

    request(requester, target)
    assert_receive {:packet_sent, %TradeRequestReceived{}, _}, 1_000

    pending = PlayerSession.get_state(target.pid).pending_trade_invite
    send(target.pid, {:trade_invite_expired, requester.character.id, pending.expires_at})

    assert_receive {:packet_sent, %TradeCancelled{reason: :TRADE_CANCEL_REASON_TIMEOUT}, _},
                   1_000

    assert PlayerSession.get_state(target.pid).pending_trade_invite == nil

    request(requester, target)
    assert_receive {:packet_sent, %TradeRequestReceived{}, _}, 1_000
    simulate_incoming_message(target.pid, %TradeResponse{accept: true})

    assert_eventually(fn -> PlayerSession.get_state(target.pid).trade != nil end)
    send(target.pid, {:trade_invite_expired, requester.character.id, 0})

    assert_eventually(fn ->
      PlayerSession.get_state(target.pid).game_state.action_state == :trading
    end)

    refute_receive {:packet_sent, %TradeCancelled{reason: :TRADE_CANCEL_REASON_TIMEOUT}, _},
                   100
  end

  test "dead, distant, and unskilled requesters are rejected" do
    target = player("GateTarget", {151, 150})

    dead = player("DeadReq", {150, 150}, hp: 0)
    request(dead, target)
    assert_cancel(:TRADE_CANCEL_REASON_DEAD)

    distant = player("FarReq", {200, 200})
    request(distant, target)
    assert_cancel(:TRADE_CANCEL_REASON_TOO_FAR)

    unskilled = player("BasicReq", {150, 150}, learned_skills: %{})
    request(unskilled, target)
    assert_cancel(:TRADE_CANCEL_REASON_INVALID)

    assert PlayerSession.get_state(target.pid).pending_trade_invite == nil
  end

  test "a target with a pending request rejects another requester" do
    first = player("PendingOne", {150, 150})
    second = player("PendingTwo", {150, 151})
    target = player("PendingTarget", {151, 150})

    request(first, target)
    assert_receive {:packet_sent, %TradeRequestReceived{name: "PendingOne"}, _}, 1_000

    request(second, target)
    assert_cancel(:TRADE_CANCEL_REASON_BUSY)

    assert PlayerSession.get_state(target.pid).pending_trade_invite.requester_char_id ==
             first.character.id
  end

  test "a player in an open trade rejects a third player's request" do
    first = player("BusyOne", {150, 150})
    target = player("BusyTarget", {151, 150})
    third = player("BusyThree", {150, 151})

    open_trade(first, target)
    request(third, target)

    assert_cancel(:TRADE_CANCEL_REASON_BUSY)
    assert PlayerSession.get_state(target.pid).game_state.action_state == :trading
  end

  test "accept re-checks distance for both participants" do
    requester = player("RecheckReq", {150, 150})
    target = player("RecheckTarget", {151, 150})

    request(requester, target)
    assert_receive {:packet_sent, %TradeRequestReceived{}, _}, 1_000

    relocate(target, {200, 200})
    simulate_incoming_message(target.pid, %TradeResponse{accept: true})

    assert_cancel(:TRADE_CANCEL_REASON_TOO_FAR)
    assert_cancel(:TRADE_CANCEL_REASON_TOO_FAR)
    assert PlayerSession.get_state(requester.pid).trade == nil
    assert PlayerSession.get_state(target.pid).trade == nil
  end

  test "a pending request does not stop the requester from moving" do
    requester = player("MovingReq", {150, 150})
    target = player("MovingTarget", {151, 150})

    request(requester, target)
    assert_receive {:packet_sent, %TradeRequestReceived{}, _}, 1_000

    simulate_incoming_message(requester.pid, %MoveRequest{dest_x: 149, dest_y: 150})

    assert_eventually(fn -> get_player_state(requester.pid).x == 149 end)
    assert PlayerSession.get_state(target.pid).pending_trade_invite != nil
  end

  test "a trade process crash clears both participants" do
    requester = player("CrashReq", {150, 150})
    target = player("CrashTarget", {151, 150})

    open_trade(requester, target)
    trade_pid = PlayerSession.get_state(requester.pid).trade.pid
    Process.exit(trade_pid, :kill)

    assert_cancel(:TRADE_CANCEL_REASON_DISCONNECTED)
    assert_cancel(:TRADE_CANCEL_REASON_DISCONNECTED)

    assert_eventually(fn ->
      requester_state = PlayerSession.get_state(requester.pid)
      target_state = PlayerSession.get_state(target.pid)

      requester_state.trade == nil and target_state.trade == nil and
        requester_state.game_state.action_state == :idle and
        target_state.game_state.action_state == :idle
    end)
  end

  defp open_trade(requester, target) do
    request(requester, target)
    assert_receive {:packet_sent, %TradeRequestReceived{}, _}, 1_000
    simulate_incoming_message(target.pid, %TradeResponse{accept: true})

    assert_eventually(fn ->
      PlayerSession.get_state(requester.pid).trade != nil and
        PlayerSession.get_state(target.pid).trade != nil
    end)
  end

  defp relocate(session, {x, y}) do
    :sys.replace_state(session.pid, fn state ->
      game_state = %{state.game_state | x: x, y: y}

      :ok =
        Movement.set_position(:player, game_state.character_id, game_state, game_state.map_name)

      %{state | game_state: game_state}
    end)
  end

  defp assert_cancel(reason) do
    assert_receive {:packet_sent, %TradeCancelled{reason: ^reason}, _}, 1_000
  end

  defp request(requester, target) do
    simulate_incoming_message(requester.pid, %TradeRequest{target_gid: target.character.id})
  end

  defp player(name, position, opts \\ []) do
    start_player_session(
      Keyword.merge(
        [name: name, position: position, learned_skills: %{"1" => 1}],
        opts
      )
    )
  end
end
