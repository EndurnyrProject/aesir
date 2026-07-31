defmodule Aesir.ZoneServer.Unit.Player.Handlers.PickupHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  @moduletag :capture_log

  alias Aesir.Net.PickupResult
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  @ground_id 4242
  @nameid 501
  @item_def %{id: @nameid, weight: 10}

  defp ground_item(id, x, y) do
    %GroundItem{
      id: id,
      nameid: @nameid,
      amount: 1,
      x: x,
      y: y,
      sub_x: 3,
      sub_y: 3,
      identified: true,
      dropped_at: 0
    }
  end

  defp state do
    %{
      connection_pid: self(),
      game_state: %{
        character_id: 1001,
        map_name: "prontera",
        x: 100,
        y: 100,
        inventory: %{},
        stats: %{}
      }
    }
  end

  defp player_session(opts \\ []) do
    %{
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: 1001,
        map_name: "prontera",
        x: 100,
        y: 100,
        inventory: %{},
        stats: %{},
        walk_path: [],
        action_state: Keyword.get(opts, :action_state, :idle),
        movement_state: Keyword.get(opts, :movement_state, :standing),
        movement_intent: Keyword.get(opts, :movement_intent, :none),
        pickup_target_id: Keyword.get(opts, :pickup_target_id)
      }
    }
  end

  test "in-range pickup gives the item, claims it, and replies OK" do
    stub(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 ->
      [ground_item(@ground_id, 101, 100)]
    end)

    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _inv, _stats, @item_def, 1 -> :ok end)

    expect(Coordinator, :claim_item, fn "prontera", @ground_id, 1001 ->
      {:ok, ground_item(@ground_id, 101, 100)}
    end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st -> {:ok, st} end)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :OK}}}
  end

  test "give failure after claim re-places the item and replies FAILED" do
    claimed = ground_item(@ground_id, 101, 100)

    stub(GroundItemStore, :query_in_range, fn _, _, _, _ -> [claimed] end)
    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> :ok end)
    stub(Coordinator, :claim_item, fn _, _, _ -> {:ok, claimed} end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st ->
      {:error, :db_error, st}
    end)

    expect(Coordinator, :drop_items, fn "prontera", [{@nameid, 1, 101, 100, true}], 101, 100 ->
      :ok
    end)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :FAILED}}}

    refute_received {:send, :world, {:pickup_result, %PickupResult{result: :OK}}}
  end

  test "item beyond 2 cells walks toward it instead of replying TOO_FAR" do
    far = ground_item(@ground_id, 105, 100)

    stub(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 -> [] end)
    stub(GroundItemStore, :get, fn "prontera", @ground_id -> {:ok, far} end)
    stub(MapCache, :get, fn "prontera" -> {:ok, :map_data} end)
    stub(Pathfinding, :find_path, fn :map_data, {100, 100}, {105, 100} -> {:ok, [{105, 100}]} end)
    reject(&Coordinator.claim_item/3)

    expect(MovementHandler, :handle_request_move, fn moving, 105, 100, opts ->
      assert Keyword.fetch!(opts, :pickup_initiated) == true

      assert %PlayerState{
               action_state: :moving_to_item,
               movement_intent: :pickup,
               pickup_target_id: @ground_id
             } = moving.game_state

      {:noreply, moving}
    end)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, player_session())
  end

  test "item not on the map replies GONE without claiming" do
    stub(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 -> [] end)
    stub(GroundItemStore, :get, fn "prontera", @ground_id -> {:error, :gone} end)
    reject(&Coordinator.claim_item/3)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, player_session())

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :GONE}}}
  end

  test "reaching the item picks it up and returns the player to idle" do
    session =
      player_session(
        action_state: :moving_to_item,
        movement_intent: :pickup,
        pickup_target_id: @ground_id
      )

    stub(GroundItemStore, :query_in_range, fn _, _, _, _ ->
      [ground_item(@ground_id, 100, 100)]
    end)

    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, @item_def, 1 -> :ok end)

    stub(Coordinator, :claim_item, fn "prontera", @ground_id, 1001 ->
      {:ok, ground_item(@ground_id, 100, 100)}
    end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st -> {:ok, st} end)

    assert {:noreply, new_state} = PickupHandler.handle_reached_item(session)

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :OK}}}

    assert %PlayerState{action_state: :idle, pickup_target_id: nil} = new_state.game_state
  end

  test "overweight pre-check replies OVERWEIGHT without claiming" do
    stub(GroundItemStore, :query_in_range, fn _, _, _, _ ->
      [ground_item(@ground_id, 100, 100)]
    end)

    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> {:error, :overweight} end)
    reject(&Coordinator.claim_item/3)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :OVERWEIGHT}}}
  end

  test "full inventory pre-check replies INVENTORY_FULL without claiming" do
    stub(GroundItemStore, :query_in_range, fn _, _, _, _ ->
      [ground_item(@ground_id, 100, 100)]
    end)

    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> {:error, :inventory_full} end)
    reject(&Coordinator.claim_item/3)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())

    assert_received {:send, :world,
                     {:pickup_result,
                      %PickupResult{ground_id: @ground_id, result: :INVENTORY_FULL}}}
  end

  test "already-claimed or expired item replies GONE" do
    stub(GroundItemStore, :query_in_range, fn _, _, _, _ ->
      [ground_item(@ground_id, 100, 100)]
    end)

    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> :ok end)
    stub(Coordinator, :claim_item, fn _, _, _ -> {:error, :gone} end)
    reject(&InventoryManager.handle_give_item/3)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :GONE}}}
  end
end
