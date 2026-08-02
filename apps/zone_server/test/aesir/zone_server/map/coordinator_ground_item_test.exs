defmodule Aesir.ZoneServer.Map.CoordinatorGroundItemTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.ItemVanished
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map_name "prontera"

  setup :setup_ets_tables

  defp register_observer(char_id, x, y) do
    state = %PlayerState{
      character_id: char_id,
      account_id: char_id + 1000,
      map_name: @map_name,
      x: x,
      y: y,
      dir: 3,
      movement_state: :standing,
      view_range: 14
    }

    SpatialIndex.add_unit(:player, char_id, x, y, @map_name)
    UnitRegistry.register_unit(:player, char_id, PlayerState, state, self())
    state
  end

  defp coordinator_state, do: %Coordinator{map_name: @map_name}

  defp set_windows(values) do
    previous =
      Enum.map(values, fn {key, _value} -> {key, Application.get_env(:zone_server, key)} end)

    Enum.each(values, fn {key, value} -> Application.put_env(:zone_server, key, value) end)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> Application.delete_env(:zone_server, key)
        {key, value} -> Application.put_env(:zone_server, key, value)
      end)
    end)
  end

  defp drop_item(opts) do
    assert {:noreply, _state} =
             Coordinator.handle_cast(
               {:drop_items, [{501, 1, 50, 50, true}], 50, 50, opts},
               coordinator_state()
             )

    assert [item] = GroundItemStore.query_in_range(@map_name, 50, 50, 0)
    item
  end

  describe "drop_items" do
    test "places public items and broadcasts ItemOnGround when ownership is omitted" do
      register_observer(1001, 50, 50)

      assert {:noreply, _state} =
               Coordinator.handle_cast(
                 {:drop_items, [{501, 3, 50, 50, false}], 50, 50, []},
                 coordinator_state()
               )

      assert [
               %GroundItem{
                 nameid: 501,
                 amount: 3,
                 x: 50,
                 y: 50,
                 identified: false,
                 owners: nil,
                 unlock_at: nil
               }
             ] = GroundItemStore.query_in_range(@map_name, 50, 50, 0)

      assert_receive {:"$gen_cast",
                      {:send_packet,
                       %ItemOnGround{
                         nameid: 501,
                         amount: 3,
                         x: 50,
                         y: 50,
                         identified: false,
                         is_falling: true
                       }}}
    end

    test "stamps normal ownership with cumulative deadlines" do
      set_windows(
        item_first_get_time: 30,
        item_second_get_time: 20,
        item_third_get_time: 10
      )

      ownership = %LootOwnership{first: 101, second: 202, third: 303}
      before_stamp = System.monotonic_time(:millisecond)
      item = drop_item(ownership: {ownership, false})
      after_stamp = System.monotonic_time(:millisecond)

      assert item.owners == {101, 202, 303}
      assert {t1, t2, t3} = item.unlock_at
      assert t1 in (before_stamp + 30)..(after_stamp + 30)
      assert t2 - t1 == 20
      assert t3 - t2 == 10
    end

    test "applies one stamp to every item in a call" do
      set_windows(
        item_first_get_time: 30,
        item_second_get_time: 20,
        item_third_get_time: 10
      )

      ownership = %LootOwnership{first: 101, second: 202, third: 303}

      assert {:noreply, _state} =
               Coordinator.handle_cast(
                 {:drop_items, [{501, 1, 50, 50, true}, {502, 1, 51, 50, true}], 50, 50,
                  ownership: {ownership, false}},
                 coordinator_state()
               )

      assert [first, second] =
               @map_name
               |> GroundItemStore.query_in_range(50, 50, 1)
               |> Enum.sort_by(& &1.nameid)

      assert first.owners == second.owners
      assert first.unlock_at == second.unlock_at
    end

    test "uses boss ownership windows" do
      set_windows(
        mvp_item_first_get_time: 70,
        mvp_item_second_get_time: 50,
        mvp_item_third_get_time: 30
      )

      ownership = %LootOwnership{first: 101, second: 202, third: 303}
      before_stamp = System.monotonic_time(:millisecond)
      item = drop_item(ownership: {ownership, true})
      after_stamp = System.monotonic_time(:millisecond)

      assert item.owners == {101, 202, 303}
      assert {t1, t2, t3} = item.unlock_at
      assert t1 in (before_stamp + 70)..(after_stamp + 70)
      assert t2 - t1 == 50
      assert t3 - t2 == 30
    end

    test "keeps all-nil ownership public" do
      ownership = %LootOwnership{first: nil, second: nil, third: nil}

      assert %GroundItem{owners: nil, unlock_at: nil} =
               drop_item(ownership: {ownership, false})
    end

    test "applies a pre-resolved stamp verbatim" do
      owners = {101, 202, 303}
      unlock_at = {1_000, 2_000, 3_000}

      assert %GroundItem{owners: ^owners, unlock_at: ^unlock_at} =
               drop_item(ownership: {owners, unlock_at})
    end

    test "keeps pre-resolved all-nil ownership public" do
      assert %GroundItem{owners: nil, unlock_at: nil} =
               drop_item(ownership: {{nil, nil, nil}, {1_000, 2_000, 3_000}})
    end

    test "does not broadcast to players out of range" do
      register_observer(1001, 50, 50)

      Coordinator.handle_cast(
        {:drop_items, [{501, 1, 200, 200, true}], 200, 200, []},
        coordinator_state()
      )

      refute_receive {:"$gen_cast", {:send_packet, %ItemOnGround{}}}
    end
  end

  describe "claim_item" do
    test "an owner claims immediately and broadcasts PICKED_UP" do
      register_observer(1001, 50, 50)
      now = System.monotonic_time(:millisecond)

      item =
        GroundItem.new(501, 1, 50, 50, true,
          owners: {1001, 2002, 3003},
          unlock_at: {now + 100, now + 200, now + 300}
        )

      GroundItemStore.put(@map_name, item)
      party_ctx = %{party_id: 0, pickup_share: false}

      assert {:reply, {:ok, %GroundItem{id: id}}, _} =
               Coordinator.handle_call(
                 {:claim_item, item.id, 1001, party_ctx},
                 {self(), nil},
                 coordinator_state()
               )

      assert id == item.id

      assert_receive {:"$gen_cast",
                      {:send_packet, %ItemVanished{ground_id: ^id, reason: :PICKED_UP}}}
    end

    test "a stranger is denied while protected without removing or broadcasting" do
      register_observer(4004, 50, 50)
      now = System.monotonic_time(:millisecond)

      item =
        GroundItem.new(501, 1, 50, 50, true,
          owners: {1001, 2002, 3003},
          unlock_at: {now + 100, now + 200, now + 300}
        )

      GroundItemStore.put(@map_name, item)
      party_ctx = %{party_id: 0, pickup_share: false}

      assert {:reply, {:error, :protected}, _} =
               Coordinator.handle_call(
                 {:claim_item, item.id, 4004, party_ctx},
                 {self(), nil},
                 coordinator_state()
               )

      assert {:ok, ^item} = GroundItemStore.get(@map_name, item.id)
      refute_receive {:"$gen_cast", {:send_packet, %ItemVanished{}}}
    end

    test "a stranger claims after the public deadline" do
      set_windows(
        item_first_get_time: 10,
        item_second_get_time: 10,
        item_third_get_time: 10
      )

      ownership = %LootOwnership{first: 1001, second: 2002, third: 3003}
      item = drop_item(ownership: {ownership, false})
      Process.sleep(100)
      party_ctx = %{party_id: 0, pickup_share: false}

      assert {:reply, {:ok, ^item}, _} =
               Coordinator.handle_call(
                 {:claim_item, item.id, 4004, party_ctx},
                 {self(), nil},
                 coordinator_state()
               )
    end

    test "a partially-nil ownership still stamps the item" do
      ownership = %LootOwnership{first: 1001, second: nil, third: nil}
      item = drop_item(ownership: {ownership, false})

      assert item.owners == {1001, nil, nil}
      assert {_t1, _t2, _t3} = item.unlock_at
    end

    test "a second claim of a stamped item returns gone" do
      now = System.monotonic_time(:millisecond)

      item =
        GroundItem.new(501, 1, 50, 50, true,
          owners: {1001, 2002, 3003},
          unlock_at: {now + 100, now + 200, now + 300}
        )

      GroundItemStore.put(@map_name, item)
      party_ctx = %{party_id: 0, pickup_share: false}

      assert {:reply, {:ok, _item}, _} =
               Coordinator.handle_call(
                 {:claim_item, item.id, 1001, party_ctx},
                 {self(), nil},
                 coordinator_state()
               )

      assert {:reply, {:error, :gone}, _} =
               Coordinator.handle_call(
                 {:claim_item, item.id, 1001, party_ctx},
                 {self(), nil},
                 coordinator_state()
               )
    end

    test "returns gone and does not broadcast for an unknown item" do
      register_observer(1001, 50, 50)
      party_ctx = %{party_id: 0, pickup_share: false}

      assert {:reply, {:error, :gone}, _} =
               Coordinator.handle_call(
                 {:claim_item, 999_999, 1001, party_ctx},
                 {self(), nil},
                 coordinator_state()
               )

      refute_receive {:"$gen_cast", {:send_packet, %ItemVanished{}}}
    end
  end

  describe "expiry sweep" do
    test "removes expired items and broadcasts ItemVanished{EXPIRED}" do
      register_observer(1001, 50, 50)

      expired = %GroundItem{
        id: 42,
        nameid: 501,
        amount: 1,
        x: 50,
        y: 50,
        sub_x: 3,
        sub_y: 3,
        identified: true,
        dropped_at: System.monotonic_time(:millisecond) - 61_000
      }

      fresh = GroundItem.new(909, 1, 50, 50)
      GroundItemStore.put(@map_name, expired)
      GroundItemStore.put(@map_name, fresh)

      assert {:noreply, _} = Coordinator.handle_info(:expire_ground_items, coordinator_state())

      assert_receive {:"$gen_cast",
                      {:send_packet, %ItemVanished{ground_id: 42, reason: :EXPIRED}}}

      remaining = GroundItemStore.query_in_range(@map_name, 50, 50, 0)
      assert [%GroundItem{id: fresh_id}] = remaining
      assert fresh_id == fresh.id
    end
  end
end
