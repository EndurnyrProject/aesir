defmodule Aesir.ZoneServer.Map.CoordinatorGroundItemTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.ItemVanished
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
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

  describe "drop_items" do
    test "places each item in the store and broadcasts ItemOnGround to in-range players" do
      register_observer(1001, 50, 50)

      assert {:noreply, _state} =
               Coordinator.handle_cast(
                 {:drop_items, [{501, 3, 50, 50}], 50, 50},
                 coordinator_state()
               )

      assert [%GroundItem{nameid: 501, amount: 3, x: 50, y: 50}] =
               GroundItemStore.query_in_range(@map_name, 50, 50, 0)

      assert_receive {:"$gen_cast",
                      {:send_packet,
                       %ItemOnGround{nameid: 501, amount: 3, x: 50, y: 50, is_falling: true}}}
    end

    test "does not broadcast to players out of range" do
      register_observer(1001, 50, 50)

      Coordinator.handle_cast({:drop_items, [{501, 1, 200, 200}], 200, 200}, coordinator_state())

      refute_receive {:"$gen_cast", {:send_packet, %ItemOnGround{}}}
    end
  end

  describe "claim_item" do
    test "returns {:ok, item} once then {:error, :gone}, broadcasting PICKED_UP on the win" do
      register_observer(1001, 50, 50)
      item = GroundItem.new(501, 1, 50, 50)
      GroundItemStore.put(@map_name, item)

      assert {:reply, {:ok, %GroundItem{id: id}}, _} =
               Coordinator.handle_call(
                 {:claim_item, item.id, 1001},
                 {self(), nil},
                 coordinator_state()
               )

      assert id == item.id

      assert_receive {:"$gen_cast",
                      {:send_packet, %ItemVanished{ground_id: ^id, reason: :PICKED_UP}}}

      assert {:reply, {:error, :gone}, _} =
               Coordinator.handle_call(
                 {:claim_item, item.id, 1001},
                 {self(), nil},
                 coordinator_state()
               )
    end

    test "does not broadcast when the item is already gone" do
      register_observer(1001, 50, 50)

      assert {:reply, {:error, :gone}, _} =
               Coordinator.handle_call(
                 {:claim_item, 999_999, 1001},
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
