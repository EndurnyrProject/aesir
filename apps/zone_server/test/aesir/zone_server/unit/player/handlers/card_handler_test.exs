defmodule Aesir.ZoneServer.Unit.Player.Handlers.CardHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  @moduletag :capture_log

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.CardComposeRequest
  alias Aesir.Net.CardComposeResult
  alias Aesir.Net.CardTargetList
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Unit.Player.Handlers.CardHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!

  test "discovery returns sorted client indices without changing or consuming inventory" do
    card = %InventoryItem{id: 1, nameid: 4001, amount: 2}
    high_target = %InventoryItem{id: 2, nameid: 1101, amount: 1, identify: 1}
    low_target = %InventoryItem{id: 3, nameid: 1101, amount: 1, identify: 1}
    state = state(%{8 => high_target, 0 => card, 2 => low_target})

    stub(Items, :by_id, &item_lookup/1)
    reject(&InventoryOps.apply_change/4)

    assert {:noreply, ^state} = CardHandler.open_picker(0, state)

    assert_received {:send, :gameplay,
                     {:card_target_list,
                      %CardTargetList{card_index: 2, equipment_indices: [4, 10]}}}
  end

  test "discovery returns an empty target list without changing session state" do
    card = %InventoryItem{id: 1, nameid: 4001, amount: 1}
    state = state(%{0 => card})

    stub(Items, :by_id, fn 4001 -> {:ok, card_definition()} end)

    assert {:noreply, ^state} = CardHandler.open_picker(0, state)

    assert_received {:send, :gameplay,
                     {:card_target_list, %CardTargetList{card_index: 2, equipment_indices: []}}}
  end

  test "every stale or forged request returns its exact compose error without changing state" do
    stub(Items, :by_id, &item_lookup/1)

    request = %CardComposeRequest{card_index: 9, equipment_index: 5}
    card = %InventoryItem{id: 1, nameid: 4001, amount: 1}
    target = %InventoryItem{id: 2, nameid: 1101, amount: 1, identify: 1}

    cases = [
      {%{}, request, :CARD_COMPOSE_CARD_NOT_FOUND},
      {%{7 => %{card | nameid: 501}, 3 => target}, request, :CARD_COMPOSE_NOT_A_CARD},
      {%{7 => %{card | equip: 2}, 3 => target}, request, :CARD_COMPOSE_SOURCE_EQUIPPED},
      {%{7 => card}, request, :CARD_COMPOSE_TARGET_NOT_FOUND},
      {%{7 => card}, %{request | equipment_index: 9}, :CARD_COMPOSE_SAME_INVENTORY_SLOT},
      {%{7 => card, 3 => %{target | nameid: 501}}, request, :CARD_COMPOSE_NOT_EQUIPMENT},
      {%{7 => card, 3 => %{target | identify: 0}}, request, :CARD_COMPOSE_TARGET_UNIDENTIFIED},
      {%{7 => card, 3 => %{target | equip: 2}}, request, :CARD_COMPOSE_TARGET_EQUIPPED},
      {%{7 => %{card | nameid: 4002}, 3 => target}, request, :CARD_COMPOSE_LOCATION_MISMATCH},
      {%{7 => card, 3 => %{target | card0: 4999, card1: 4998}}, request,
       :CARD_COMPOSE_NO_FREE_SOCKET}
    ]

    for {inventory, compose_request, expected_code} <- cases do
      state = state(inventory)

      assert {:noreply, ^state} = CardHandler.handle_compose(compose_request, state)

      assert_received {:send, :gameplay,
                       {:card_compose_result,
                        %CardComposeResult{
                          card_index: 9,
                          equipment_index: equipment_index,
                          code: ^expected_code,
                          cards: []
                        }}}

      assert equipment_index == compose_request.equipment_index
      refute_received {:send, :gameplay, {:item_removed, _}}
      refute_received {:send, :gameplay, {:param_change, _}}
    end
  end

  test "successful compose commits persisted inventory and publishes ordered authoritative updates" do
    :ok = Phoenix.PubSub.subscribe(Aesir.PubSub, "player:1000")
    stub(Items, :by_id, &item_lookup/1)
    reject(&Stats.calculate_stats/3)

    card = %InventoryItem{id: 1, nameid: 4001, amount: 2}

    target = %InventoryItem{
      id: 2,
      nameid: 1101,
      amount: 1,
      identify: 1,
      card0: 4111,
      card2: 4222,
      card3: 4333
    }

    inventory = %{7 => card, 3 => target}
    state = state(inventory)
    request = %CardComposeRequest{card_index: 9, equipment_index: 5}
    test_pid = self()

    expect(PlayerState, :server_index, 2, fn
      9 -> 7
      5 -> 3
    end)

    expect(InventoryOps, :apply_change, fn
      1000,
      ^inventory,
      %{7 => %InventoryItem{amount: 1}, 3 => %InventoryItem{card1: 4001}} = next,
      {:card_compounded, 7, 3, :card1} ->
        persisted =
          next
          |> put_in([3, Access.key!(:card3)], 4444)
          |> Map.put(11, %InventoryItem{id: 3, nameid: 501, amount: 1})

        send(test_pid, :inventory_persisted)
        {:ok, persisted}
    end)

    expect(UnitRegistry, :update_unit_state, fn :player, 1000, game_state ->
      send(test_pid, {:state_committed, game_state})
      :ok
    end)

    assert {:noreply, committed} = CardHandler.handle_compose(request, state)
    assert committed.game_state.inventory[7].amount == 1
    assert committed.game_state.inventory[3].card1 == 4001
    assert committed.game_state.inventory[3].card3 == 4444
    assert committed.game_state.inventory[11].nameid == 501
    assert committed.game_state.stats == state.game_state.stats

    assert :inventory_persisted = next_message()
    assert {:state_committed, %{inventory: committed_inventory}} = next_message()
    assert committed_inventory == committed.game_state.inventory

    assert {:send, :gameplay, {:item_removed, %ItemRemoved{index: 9, amount: 1}}} =
             next_message()

    assert {:send, :gameplay,
            {:card_compose_result,
             %CardComposeResult{
               card_index: 9,
               equipment_index: 5,
               code: :CARD_COMPOSE_SUCCESS,
               cards: [4111, 4001, 4222, 4444]
             }}} = next_message()

    assert {:send, :gameplay, {:param_change, %ParamChange{var_id: weight_param, value: 117}}} =
             next_message()

    assert weight_param == StatusParams.weight()
    assert :inventory_changed = next_message()
    refute_received {:send, :gameplay, {:item_use_result, _}}
  end

  test "persistence failure emits only the persistence result and preserves session state" do
    :ok = Phoenix.PubSub.subscribe(Aesir.PubSub, "player:1000")
    stub(Items, :by_id, &item_lookup/1)
    reject(&Stats.calculate_stats/3)
    reject(&UnitRegistry.update_unit_state/3)

    card = %InventoryItem{id: 1, nameid: 4001, amount: 1}
    target = %InventoryItem{id: 2, nameid: 1101, amount: 1, identify: 1}
    inventory = %{7 => card, 3 => target}
    state = state(inventory)
    request = %CardComposeRequest{card_index: 9, equipment_index: 5}

    expect(PlayerState, :server_index, 2, fn
      9 -> 7
      5 -> 3
    end)

    expect(InventoryOps, :apply_change, fn
      1000, ^inventory, %{3 => %InventoryItem{card0: 4001}}, {:card_compounded, 7, 3, :card0} ->
        {:error, {:db, :timeout}}
    end)

    log =
      capture_log(fn ->
        assert {:noreply, ^state} = CardHandler.handle_compose(request, state)
      end)

    assert log =~
             "Card compose persist failed for character 1000 " <>
               "(source inventory row 1 at slot 7, target inventory row 2 at slot 3): " <>
               "{:db, :timeout}"

    assert_received {:send, :gameplay,
                     {:card_compose_result,
                      %CardComposeResult{
                        card_index: 9,
                        equipment_index: 5,
                        code: :CARD_COMPOSE_PERSISTENCE_FAILED,
                        cards: []
                      }}}

    refute_received {:send, :gameplay, {:item_removed, _}}
    refute_received {:send, :gameplay, {:param_change, _}}
    refute_received :inventory_changed
  end

  test "compose is rejected while item use is disabled" do
    stub(Items, :by_id, &item_lookup/1)
    reject(&InventoryOps.apply_change/4)

    card = %InventoryItem{id: 1, nameid: 4001, amount: 1}
    target = %InventoryItem{id: 2, nameid: 1101, amount: 1, identify: 1}
    state = state(%{7 => card, 3 => target}, %{disable_item_use: true})
    request = %CardComposeRequest{card_index: 9, equipment_index: 5}

    expect(PlayerState, :server_index, 2, fn
      9 -> 7
      5 -> 3
    end)

    assert {:noreply, ^state} = CardHandler.handle_compose(request, state)

    assert_received {:send, :gameplay,
                     {:card_compose_result,
                      %CardComposeResult{code: :CARD_COMPOSE_ITEM_USE_DISABLED, cards: []}}}

    refute_received {:send, :gameplay, {:item_removed, _}}
    refute_received {:send, :gameplay, {:param_change, _}}
  end

  defp next_message do
    receive do
      message -> message
    after
      100 -> flunk("expected another ordered card-compose message")
    end
  end

  defp state(inventory, game_state_attrs \\ %{}) do
    game_state =
      struct!(
        PlayerState,
        Map.merge(%{character_id: 1000, inventory: inventory}, game_state_attrs)
      )

    %SessionState{connection_pid: self(), game_state: game_state}
  end

  defp card_definition(id \\ 4001, locations \\ [:right_hand]) do
    %ItemDefinition{
      id: id,
      aegis_name: "Card_#{id}",
      name: "Card #{id}",
      type: :card,
      weight: 10,
      locations: locations
    }
  end

  defp item_lookup(4001), do: {:ok, card_definition()}
  defp item_lookup(4002), do: {:ok, card_definition(4002, [:armor])}

  defp item_lookup(1101) do
    {:ok,
     %ItemDefinition{
       id: 1101,
       aegis_name: "Sword",
       name: "Sword",
       type: :weapon,
       weight: 100,
       locations: [:right_hand],
       slots: 2
     }}
  end

  defp item_lookup(501) do
    {:ok,
     %ItemDefinition{
       id: 501,
       aegis_name: "Red_Potion",
       name: "Red Potion",
       type: :healing,
       weight: 7
     }}
  end

  defp item_lookup(_id), do: :error
end
