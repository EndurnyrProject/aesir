defmodule Aesir.ZoneServer.Unit.Trade.SessionTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Trade.Exchange
  alias Aesir.ZoneServer.Unit.Trade.Session

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    side_a = relay(:a, self())
    side_b = relay(:b, self())

    on_exit(fn ->
      Process.exit(side_a, :kill)
      Process.exit(side_b, :kill)
    end)

    %{side_a: side_a, side_b: side_b}
  end

  test "opens the trade for both participants", %{side_a: side_a, side_b: side_b} do
    assert {:ok, trade} = start_trade(side_a, side_b)

    assert_receive {:a, {:trade, {:opened, ^trade, 202}}}
    assert_receive {:b, {:trade, {:opened, ^trade, 101}}}
  end

  test "uses a temporary worker child spec", %{side_a: side_a, side_b: side_b} do
    init_arg = init_arg(side_a, side_b)

    assert %{
             restart: :temporary,
             type: :worker,
             start: {Session, :start_link, [^init_arg]}
           } = Session.child_spec(init_arg)
  end

  test "mutations update both participant views", %{side_a: side_a, side_b: side_b} do
    trade = start_opened_trade(side_a, side_b)
    item = %InventoryItem{id: 42, amount: 5}

    assert session_call(side_a, fn -> Session.add_item(trade, item, 2) end) == :ok

    assert_views(
      %{own: %{entries: [%{row_id: 42, amount: 2, snapshot: item}]}},
      %{partner: %{entries: [%{row_id: 42, amount: 2, snapshot: item}]}}
    )

    assert session_call(side_a, fn -> Session.set_zeny(trade, 5_000) end) == :ok
    assert_views(%{own: %{zeny: 5_000}}, %{partner: %{zeny: 5_000}})

    assert session_call(side_a, fn -> Session.remove_item(trade, 42) end) == :ok
    assert_views(%{own: %{entries: []}}, %{partner: %{entries: []}})
  end

  test "rejects unknown callers and illegal building calls", %{side_a: side_a, side_b: side_b} do
    trade = start_opened_trade(side_a, side_b)
    item = %InventoryItem{id: 1}

    assert Session.add_item(trade, item, 1) == {:error, :not_a_participant}

    assert session_call(side_a, fn -> Session.confirm(trade, snapshot(:a)) end) ==
             {:error, :not_locked}

    assert session_call(side_a, fn -> Session.lock(trade) end) == :ok
    assert_views(%{own: %{locked: true}}, %{partner: %{locked: true}})
    assert session_call(side_a, fn -> Session.lock(trade) end) == :ok

    assert session_call(side_a, fn -> Session.add_item(trade, item, 1) end) ==
             {:error, :locked}

    assert session_call(side_a, fn -> Session.set_zeny(trade, 1) end) ==
             {:error, :locked}
  end

  test "both locks are visible and locked offers cannot mutate", %{
    side_a: side_a,
    side_b: side_b
  } do
    trade = start_opened_trade(side_a, side_b)

    assert session_call(side_a, fn -> Session.lock(trade) end) == :ok

    assert_views(
      %{own: %{locked: true}, partner: %{locked: false}},
      %{own: %{locked: false}, partner: %{locked: true}}
    )

    assert session_call(side_b, fn -> Session.lock(trade) end) == :ok

    assert_views(
      %{own: %{locked: true}, partner: %{locked: true}},
      %{own: %{locked: true}, partner: %{locked: true}}
    )

    assert session_call(side_b, fn -> Session.remove_item(trade, 1) end) ==
             {:error, :locked}

    assert session_call(side_a, fn -> Session.lock(trade) end) == {:error, :locked}
  end

  test "second confirm exchanges once and completes both sides", %{
    side_a: side_a,
    side_b: side_b
  } do
    parent = self()
    delta_a = %{inventory: :inventory_a, item_changes: [:a], zeny: 10}
    delta_b = %{inventory: :inventory_b, item_changes: [:b], zeny: 20}

    expect(Exchange, :run, fn side_a_data, side_b_data ->
      send(parent, {:exchange_sides, side_a_data, side_b_data})
      {:ok, %{a: delta_a, b: delta_b}}
    end)

    trade = start_opened_trade(side_a, side_b)
    allow(Exchange, self(), trade)
    lock_both(trade, side_a, side_b)

    monitor = Process.monitor(trade)
    assert session_call(side_a, fn -> Session.confirm(trade, snapshot(:a)) end) == :ok
    assert Process.alive?(trade)
    assert session_call(side_b, fn -> Session.confirm(trade, snapshot(:b)) end) == :ok

    assert_receive {:exchange_sides, %{char_id: 101, inventory: :inventory_a, stats: :stats_a},
                    %{char_id: 202, inventory: :inventory_b, stats: :stats_b}}

    assert_receive {:a, {:trade, {:completed, ^delta_a}}}
    assert_receive {:b, {:trade, {:completed, ^delta_b}}}
    assert_receive {:DOWN, ^monitor, :process, ^trade, :normal}
  end

  test "an exchange error cancels both sides", %{side_a: side_a, side_b: side_b} do
    expect(Exchange, :run, fn _, _ -> {:error, :overweight} end)

    trade = start_opened_trade(side_a, side_b)
    allow(Exchange, self(), trade)
    lock_both(trade, side_a, side_b)

    assert session_call(side_a, fn -> Session.confirm(trade, snapshot(:a)) end) == :ok
    assert session_call(side_b, fn -> Session.confirm(trade, snapshot(:b)) end) == :ok

    assert_receive {:a, {:trade, {:cancelled, :overweight}}}
    assert_receive {:b, {:trade, {:cancelled, :overweight}}}
  end

  test "confirm replay cannot run the exchange twice", %{side_a: side_a, side_b: side_b} do
    parent = self()
    delta = %{inventory: %{}, item_changes: [], zeny: 0}

    expect(Exchange, :run, fn _, _ ->
      send(parent, {:exchange_started, self()})

      receive do
        :finish_exchange -> {:ok, %{a: delta, b: delta}}
      end
    end)

    trade = start_opened_trade(side_a, side_b)
    allow(Exchange, self(), trade)
    lock_both(trade, side_a, side_b)

    assert session_call(side_a, fn -> Session.confirm(trade, snapshot(:a)) end) == :ok

    ref_a = session_call_async(side_a, fn -> Session.confirm(trade, snapshot(:a)) end)
    ref_b = session_call_async(side_b, fn -> Session.confirm(trade, snapshot(:b)) end)
    assert_receive {:exchange_started, ^trade}

    send(trade, :finish_exchange)
    assert_receive {:a, {:trade, {:completed, ^delta}}}
    assert_receive {:b, {:trade, {:completed, ^delta}}}

    results = [await_session_call(ref_a), await_session_call(ref_b)]
    assert :ok in results
    assert Enum.all?(results, &(&1 == :ok or match?({:exit, _}, &1)))
  end

  test "cancel stops building and locked trades", %{side_a: side_a, side_b: side_b} do
    for phase <- [:building, :locked] do
      trade = start_opened_trade(side_a, side_b)
      monitor = Process.monitor(trade)

      if phase == :locked, do: lock_both(trade, side_a, side_b)

      assert :ok = session_call(side_a, fn -> Session.cancel(trade, :cancelled) end)
      assert_receive {:a, {:trade, {:cancelled, :cancelled}}}
      assert_receive {:b, {:trade, {:cancelled, :cancelled}}}
      assert_receive {:DOWN, ^monitor, :process, ^trade, :normal}
    end
  end

  test "a participant disconnect cancels the trade", %{side_a: side_a, side_b: side_b} do
    trade = start_opened_trade(side_a, side_b)
    monitor = Process.monitor(trade)

    Process.exit(side_a, :kill)

    assert_receive {:b, {:trade, {:cancelled, :disconnected}}}
    assert_receive {:DOWN, ^monitor, :process, ^trade, reason}
    assert reason in [:normal, :noproc]
  end

  defp start_opened_trade(side_a, side_b) do
    assert {:ok, trade} = start_trade(side_a, side_b)
    assert_receive {:a, {:trade, {:opened, ^trade, 202}}}
    assert_receive {:b, {:trade, {:opened, ^trade, 101}}}
    trade
  end

  defp start_trade(side_a, side_b), do: Session.start_link(init_arg(side_a, side_b))

  defp init_arg(side_a, side_b) do
    %{
      a: %{pid: side_a, char_id: 101},
      b: %{pid: side_b, char_id: 202}
    }
  end

  defp lock_both(trade, side_a, side_b) do
    assert session_call(side_a, fn -> Session.lock(trade) end) == :ok
    assert_views(%{own: %{locked: true}}, %{partner: %{locked: true}})
    assert session_call(side_b, fn -> Session.lock(trade) end) == :ok
    assert_views(%{own: %{locked: true}}, %{own: %{locked: true}})
  end

  defp assert_views(expected_a, expected_b) do
    assert_receive {:a, {:trade, {:offer_update, actual_a}}}
    assert_receive {:b, {:trade, {:offer_update, actual_b}}}
    assert_view(actual_a, expected_a)
    assert_view(actual_b, expected_b)
  end

  defp assert_view(actual, expected) when is_map(expected) do
    Enum.each(expected, fn {key, expected_value} ->
      assert Map.has_key?(actual, key)
      assert_view(actual[key], expected_value)
    end)
  end

  defp assert_view(actual, expected), do: assert(actual == expected)

  defp session_call(session, function) do
    session
    |> session_call_async(function)
    |> await_session_call()
  end

  defp session_call_async(session, function) do
    ref = make_ref()
    send(session, {:invoke, self(), ref, function})
    ref
  end

  defp await_session_call(ref) do
    receive do
      {^ref, result} -> result
    end
  end

  defp snapshot(:a), do: %{inventory: :inventory_a, stats: :stats_a}
  defp snapshot(:b), do: %{inventory: :inventory_b, stats: :stats_b}

  defp relay(side, owner) do
    spawn(fn -> relay_loop(side, owner) end)
  end

  defp relay_loop(side, owner) do
    receive do
      {:invoke, caller, ref, function} ->
        result =
          try do
            function.()
          catch
            :exit, reason -> {:exit, reason}
          end

        send(caller, {ref, result})
        relay_loop(side, owner)

      message ->
        send(owner, {side, message})
        relay_loop(side, owner)
    end
  end
end
