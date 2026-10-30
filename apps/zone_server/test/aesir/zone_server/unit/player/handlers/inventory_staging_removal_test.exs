defmodule Aesir.ZoneServer.Unit.Player.Handlers.InventoryStagingRemovalTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryStaging
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  test "committed_removals_notify_without_second_write" do
    reject(&InventoryOps.apply_change/4)
    state = %PlayerState{inventory: %{}, pending_inventory_notify: [{:removed, 0, 1}]}
    drained = InventoryStaging.drain(self(), state)

    assert_received {:send, :gameplay,
                     {:item_removed, %ItemRemoved{index: 2, amount: 1, reason: 0}}}

    assert drained.pending_inventory_notify == []
    assert drained.pending_inventory_persist == []
    assert InventoryStaging.drain(self(), drained) == drained
    refute_received {:send, _, _}
  end

  test "partial_stack_removal_sends_only_removed_amount" do
    state = %PlayerState{
      inventory: %{3 => %InventoryItem{nameid: 1_010, amount: 7}},
      pending_inventory_notify: [{:removed, 3, 1}]
    }

    drained = InventoryStaging.drain(self(), state)
    assert_received {:send, :gameplay, {:item_removed, %ItemRemoved{index: 5, amount: 1}}}
    refute_received {:send, _, {:item_added, _}}
    assert drained.inventory[3].amount == 7
  end

  test "mixed_committed_notifications_keep_order" do
    weapon = %InventoryItem{nameid: 1_101, amount: 1, identify: 1, refine: 1}

    for last <- [{:added, 0, weapon}, {:removed, 0, 1}] do
      state = %PlayerState{
        inventory: %{0 => weapon},
        pending_inventory_notify: [{:removed, 1, 1}, last]
      }

      assert %{pending_inventory_notify: []} = InventoryStaging.drain(self(), state)
      assert_receive {:send, :gameplay, first}
      assert {:item_removed, %ItemRemoved{index: 3, amount: 1}} = first

      case last do
        {:added, _, _} ->
          assert_receive {:send, :gameplay, {:item_added, %ItemAdded{index: 2, refine: 1}}}

        {:removed, _, _} ->
          assert_receive {:send, :gameplay, {:item_removed, %ItemRemoved{index: 2, amount: 1}}}
      end

      refute_received {:send, _, _}
    end

    state = %PlayerState{}
    assert InventoryStaging.drain(self(), state) == state
    refute_received {:send, _, _}
  end
end
