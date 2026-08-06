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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :stub_pickup_gate

  @ground_id 4242
  @nameid 501
  @item_def %{id: @nameid, weight: 10}

  defp stub_pickup_gate(_context) do
    stub(StatusInterpreter, :has_active_flag?, fn :player, 1001, :no_pick_item -> false end)
    :ok
  end

  defp ground_item(id, x, y, identified \\ true) do
    %GroundItem{
      id: id,
      nameid: @nameid,
      amount: 1,
      x: x,
      y: y,
      sub_x: 3,
      sub_y: 3,
      identified: identified,
      dropped_at: 0
    }
  end

  defp state(opts \\ []) do
    %{
      connection_pid: self(),
      game_state: %{
        character_id: 1001,
        party_id: Keyword.get(opts, :party_id, 0),
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

  test "initial pickup rejects an active no-pick-item flag without looking up or claiming" do
    expect(StatusInterpreter, :has_active_flag?, fn :player, 1001, :no_pick_item -> true end)
    reject(&GroundItemStore.query_in_range/4)
    reject(&Coordinator.claim_item/4)

    assert {:noreply, returned} = PickupHandler.handle_pickup(@ground_id, state())
    assert returned == state()

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :FAILED}}}
  end

  test "arrival rejects a no-pick-item flag gained while walking without claiming" do
    session =
      player_session(
        action_state: :moving_to_item,
        movement_intent: :pickup,
        pickup_target_id: @ground_id
      )

    expect(StatusInterpreter, :has_active_flag?, fn :player, 1001, :no_pick_item -> true end)
    reject(&Coordinator.claim_item/4)

    assert {:noreply, returned} = PickupHandler.handle_reached_item(session)

    assert %PlayerState{action_state: :idle, pickup_target_id: nil} = returned.game_state

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :FAILED}}}
  end

  test "in-range pickup gives the item, claims it, and replies OK" do
    stub(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 ->
      [ground_item(@ground_id, 101, 100)]
    end)

    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _inv, _stats, @item_def, 1 -> :ok end)

    reject(&PartyManager.get/1)

    expect(Coordinator, :claim_item, fn "prontera",
                                        @ground_id,
                                        1001,
                                        %{party_id: 0, pickup_share: false} ->
      {:ok, ground_item(@ground_id, 101, 100)}
    end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st, true -> {:ok, st} end)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())
  end

  test "picking up an unidentified item gives it as unidentified" do
    unidentified = ground_item(@ground_id, 101, 100, false)

    stub(GroundItemStore, :query_in_range, fn _, _, _, _ -> [unidentified] end)
    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> :ok end)
    stub(Coordinator, :claim_item, fn _, _, _, _ -> {:ok, unidentified} end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st, false -> {:ok, st} end)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :OK}}}
  end

  test "give failure after claim re-places the item and replies FAILED" do
    claimed = ground_item(@ground_id, 101, 100)

    stub(GroundItemStore, :query_in_range, fn _, _, _, _ -> [claimed] end)
    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> :ok end)
    stub(Coordinator, :claim_item, fn _, _, _, _ -> {:ok, claimed} end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st, true ->
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
    reject(&Coordinator.claim_item/4)

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
    reject(&Coordinator.claim_item/4)

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
    reject(&PartyManager.get/1)

    stub(Coordinator, :claim_item, fn "prontera",
                                      @ground_id,
                                      1001,
                                      %{party_id: 0, pickup_share: false} ->
      {:ok, ground_item(@ground_id, 100, 100)}
    end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st, true -> {:ok, st} end)

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
    reject(&Coordinator.claim_item/4)

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
    reject(&Coordinator.claim_item/4)

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
    stub(Coordinator, :claim_item, fn _, _, _, _ -> {:error, :gone} end)
    reject(&InventoryManager.handle_give_item/3)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())

    assert_received {:send, :world,
                     {:pickup_result, %PickupResult{ground_id: @ground_id, result: :GONE}}}
  end

  test "partied pickup passes the live pickup-share flag to the claim" do
    party = %PartyState{
      party_id: 77,
      name: "Vanguard",
      leader_char_id: 1001,
      exp_share: false,
      item_pickup_share: true,
      members: %{}
    }

    stub(GroundItemStore, :query_in_range, fn _, _, _, _ ->
      [ground_item(@ground_id, 101, 100)]
    end)

    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> :ok end)
    expect(PartyManager, :get, fn 77 -> {:ok, party} end)

    expect(Coordinator, :claim_item, fn "prontera",
                                        @ground_id,
                                        1001,
                                        %{party_id: 77, pickup_share: true} ->
      {:ok, ground_item(@ground_id, 101, 100)}
    end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st, true -> {:ok, st} end)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state(party_id: 77))
  end

  test "missing party state falls back to the solo claim context" do
    stub(GroundItemStore, :query_in_range, fn _, _, _, _ ->
      [ground_item(@ground_id, 101, 100)]
    end)

    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> :ok end)
    expect(PartyManager, :get, fn 77 -> {:error, :not_found} end)

    expect(Coordinator, :claim_item, fn "prontera",
                                        @ground_id,
                                        1001,
                                        %{party_id: 0, pickup_share: false} ->
      {:ok, ground_item(@ground_id, 101, 100)}
    end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st, true -> {:ok, st} end)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state(party_id: 77))
  end

  test "protected arrival pickup replies LOOT_PROTECTED and clears the pickup intent" do
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
    stub(InventoryOps, :can_add, fn _, _, _, _ -> :ok end)
    reject(&PartyManager.get/1)

    expect(Coordinator, :claim_item, fn "prontera",
                                        @ground_id,
                                        1001,
                                        %{party_id: 0, pickup_share: false} ->
      {:error, :protected}
    end)

    reject(&InventoryManager.handle_give_item/4)

    assert {:noreply, new_state} = PickupHandler.handle_reached_item(session)

    assert_received {:send, :world,
                     {:pickup_result,
                      %PickupResult{ground_id: @ground_id, result: :LOOT_PROTECTED}}}

    assert %PlayerState{action_state: :idle, pickup_target_id: nil} = new_state.game_state
  end

  test "give failure after claim preserves the ownership stamp on the re-drop" do
    claimed = %{
      ground_item(@ground_id, 101, 100)
      | owners: {1001, 1002, nil},
        unlock_at: {10_000, 12_000, 14_000}
    }

    stub(GroundItemStore, :query_in_range, fn _, _, _, _ -> [claimed] end)
    stub(ItemManagement, :get_item_by_id, fn @nameid -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _, _, _, _ -> :ok end)
    reject(&PartyManager.get/1)

    expect(Coordinator, :claim_item, fn "prontera",
                                        @ground_id,
                                        1001,
                                        %{party_id: 0, pickup_share: false} ->
      {:ok, claimed}
    end)

    expect(InventoryManager, :handle_give_item, fn @item_def, 1, st, true ->
      {:error, :db_error, st}
    end)

    expect(Coordinator, :drop_items, fn "prontera",
                                        [{@nameid, 1, 101, 100, true}],
                                        101,
                                        100,
                                        ownership: {{1001, 1002, nil}, {10_000, 12_000, 14_000}} ->
      :ok
    end)

    assert {:noreply, _state} = PickupHandler.handle_pickup(@ground_id, state())
  end
end
