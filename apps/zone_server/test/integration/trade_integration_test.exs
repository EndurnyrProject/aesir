defmodule Aesir.ZoneServer.Integration.TradeIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.ParamChange
  alias Aesir.Net.TradeAddItem
  alias Aesir.Net.TradeCancel
  alias Aesir.Net.TradeCancelled
  alias Aesir.Net.TradeCompleted
  alias Aesir.Net.TradeConfirm
  alias Aesir.Net.TradeLock
  alias Aesir.Net.TradeOfferUpdate
  alias Aesir.Net.TradeOpened
  alias Aesir.Net.TradeRequest
  alias Aesir.Net.TradeRequestReceived
  alias Aesir.Net.TradeResponse
  alias Aesir.Net.TradeSetZeny
  alias Aesir.Repo
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Trade.Supervisor, as: TradeSupervisor

  test "both players exchange attributed items and zeny over the packet path" do
    {a, [a_row]} =
      persisted_player("TradeHappyA", {150, 150}, 1_000, [
        %{nameid: 1101, amount: 1, identify: 1, refine: 7, card0: 4001}
      ])

    {b, [b_row]} =
      persisted_player("TradeHappyB", {151, 150}, 2_000, [
        %{nameid: 501, amount: 5, identify: 1}
      ])

    open_trade(a, b)
    trade_pid = PlayerSession.get_state(a.pid).trade.pid
    flush_packets()

    simulate_incoming_message(a.pid, %TradeAddItem{
      index: client_index(a.pid, a_row.id),
      amount: 1
    })

    assert_offer_pair(fn update ->
      Enum.any?(update.own, &(&1.refine == 7 and &1.cards == [4001, 0, 0, 0]))
    end)

    simulate_incoming_message(a.pid, %TradeSetZeny{amount: 100})
    assert_offer_pair(fn update -> update.own_zeny == 100 or update.partner_zeny == 100 end)

    simulate_incoming_message(b.pid, %TradeAddItem{
      index: client_index(b.pid, b_row.id),
      amount: 2
    })

    assert_offer_pair(fn update ->
      Enum.any?(update.own ++ update.partner, &(&1.nameid == 501 and &1.amount == 2))
    end)

    simulate_incoming_message(b.pid, %TradeSetZeny{amount: 250})
    assert_offer_pair(fn update -> update.own_zeny == 250 or update.partner_zeny == 250 end)

    simulate_incoming_message(a.pid, %TradeLock{})
    assert_offer_pair(fn update -> update.own_locked or update.partner_locked end)
    simulate_incoming_message(b.pid, %TradeLock{})
    assert_offer_pair(fn update -> update.own_locked and update.partner_locked end)

    simulate_incoming_message(a.pid, %TradeConfirm{})
    simulate_incoming_message(b.pid, %TradeConfirm{})

    assert length(collect_packets_of_type(ItemRemoved, 100)) == 2
    assert length(collect_packets_of_type(ItemAdded, 100)) == 2
    assert length(collect_packets_of_type(ParamChange, 100)) == 2
    assert length(collect_packets_of_type(TradeCompleted, 100)) == 2

    assert_eventually(fn ->
      a_state = PlayerSession.get_state(a.pid)
      b_state = PlayerSession.get_state(b.pid)

      a_state.trade == nil and b_state.trade == nil and
        a_state.game_state.action_state == :idle and b_state.game_state.action_state == :idle and
        not Process.alive?(trade_pid)
    end)

    a_state = PlayerSession.get_state(a.pid).game_state
    b_state = PlayerSession.get_state(b.pid).game_state
    assert a_state.zeny == 1_150
    assert b_state.zeny == 1_850
    assert Repo.get!(Character, a.character.id).zeny == 1_150
    assert Repo.get!(Character, b.character.id).zeny == 1_850
    assert inventory_rows(a_state.inventory) == persisted_rows(a.character.id)
    assert inventory_rows(b_state.inventory) == persisted_rows(b.character.id)

    assert Enum.any?(Map.values(b_state.inventory), fn item ->
             item.nameid == 1101 and item.refine == 7 and item.card0 == 4001
           end)
  end

  test "locked offers reject mutation and confirm waits for both locks" do
    {a, [row]} =
      persisted_player("TradeLockedA", {150, 150}, 500, [
        %{nameid: 501, amount: 2, identify: 1}
      ])

    {b, []} = persisted_player("TradeLockedB", {151, 150}, 500, [])
    open_trade(a, b)
    flush_packets()

    simulate_incoming_message(a.pid, %TradeLock{})
    assert_offer_pair(fn update -> update.own_locked or update.partner_locked end)

    simulate_incoming_message(a.pid, %TradeAddItem{index: client_index(a.pid, row.id), amount: 1})
    simulate_incoming_message(a.pid, %TradeConfirm{})
    refute_receive {:packet_sent, %TradeOfferUpdate{}, _}, 100
    refute_receive {:packet_sent, %TradeCompleted{}, _}, 100

    assert PlayerSession.get_state(a.pid).game_state.action_state == :trading
    assert PlayerSession.get_state(b.pid).game_state.action_state == :trading

    simulate_incoming_message(b.pid, %TradeSetZeny{amount: 1})

    assert_offer_pair(fn update ->
      update.own == [] and update.partner == [] and
        (update.own_zeny == 1 or update.partner_zeny == 1)
    end)
  end

  test "invalid local offers never change the trade offer" do
    {a, [bound, plain]} =
      persisted_player("TradeInvalidA", {150, 150}, 100, [
        %{nameid: 501, amount: 1, identify: 1, bound: 1},
        %{nameid: 502, amount: 2, identify: 1}
      ])

    {b, []} = persisted_player("TradeInvalidB", {151, 150}, 100, [])
    open_trade(a, b)
    flush_packets()

    simulate_incoming_message(a.pid, %TradeAddItem{
      index: client_index(a.pid, bound.id),
      amount: 1
    })

    simulate_incoming_message(a.pid, %TradeAddItem{
      index: client_index(a.pid, plain.id),
      amount: 3
    })

    simulate_incoming_message(a.pid, %TradeSetZeny{amount: 101})
    refute_receive {:packet_sent, %TradeOfferUpdate{}, _}, 100

    simulate_incoming_message(a.pid, %TradeLock{})

    assert_offer_pair(fn update ->
      update.own == [] and update.partner == [] and update.own_zeny == 0 and
        update.partner_zeny == 0
    end)
  end

  test "explicit cancel mid-offer leaves inventories and balances unchanged" do
    {a, [row]} =
      persisted_player("TradeCancelA", {150, 150}, 700, [
        %{nameid: 501, amount: 3, identify: 1}
      ])

    {b, []} = persisted_player("TradeCancelB", {151, 150}, 900, [])
    before_a = persisted_rows(a.character.id)
    before_b = persisted_rows(b.character.id)
    open_trade(a, b)
    flush_packets()

    simulate_incoming_message(a.pid, %TradeAddItem{index: client_index(a.pid, row.id), amount: 2})
    assert_offer_pair(fn update -> update.own != [] or update.partner != [] end)
    simulate_incoming_message(a.pid, %TradeSetZeny{amount: 300})
    assert_offer_pair(fn update -> update.own_zeny == 300 or update.partner_zeny == 300 end)
    simulate_incoming_message(a.pid, %TradeCancel{})

    assert_cancel(:TRADE_CANCEL_REASON_CANCELLED)
    assert_cancel(:TRADE_CANCEL_REASON_CANCELLED)

    assert_eventually(fn ->
      a_state = PlayerSession.get_state(a.pid)
      b_state = PlayerSession.get_state(b.pid)

      a_state.trade == nil and b_state.trade == nil and
        a_state.game_state.action_state == :idle and b_state.game_state.action_state == :idle
    end)

    assert persisted_rows(a.character.id) == before_a
    assert persisted_rows(b.character.id) == before_b
    assert Repo.get!(Character, a.character.id).zeny == 700
    assert Repo.get!(Character, b.character.id).zeny == 900
  end

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

  defp assert_offer_pair(predicate) do
    updates = collect_packets_of_type(TradeOfferUpdate, 100)
    assert length(updates) == 2
    assert Enum.any?(updates, predicate)
  end

  defp client_index(pid, row_id) do
    state = PlayerSession.get_state(pid).game_state
    {index, _row} = Enum.find(state.inventory, fn {_index, row} -> row.id == row_id end)
    index + 2
  end

  defp persisted_player(name, position, zeny, item_attrs) do
    suffix = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "tr#{suffix}",
        user_pass: "password",
        sex: "M",
        email: "tr#{suffix}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        class: 0,
        base_level: 1,
        name: name,
        zeny: zeny,
        learned_skills: %{"1" => 1},
        last_map: "prontera",
        last_x: elem(position, 0),
        last_y: elem(position, 1)
      }
      |> Character.new()
      |> Repo.insert()

    rows =
      Enum.map(item_attrs, fn attrs ->
        {:ok, row} = Persistence.insert_item(character.id, attrs)
        row
      end)

    session = start_player_session(character: character, position: position)
    {session, rows}
  end

  defp persisted_rows(char_id) do
    char_id |> Persistence.load_inventory() |> Enum.map(&row_view/1) |> Enum.sort()
  end

  defp inventory_rows(inventory) do
    inventory |> Map.values() |> Enum.map(&row_view/1) |> Enum.sort()
  end

  defp row_view(row) do
    Map.take(row, [:id, :char_id, :nameid, :amount, :refine, :card0, :bound])
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
