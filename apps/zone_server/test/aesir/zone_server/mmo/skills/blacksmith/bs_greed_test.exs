defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsGreedTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsGreed
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  @item_def %ItemDefinition{id: 501, aegis_name: "Red_Potion", name: "Red Potion", weight: 10}

  test "collects every ground item within Manhattan radius 2 into inventory" do
    items = [ground_item(1, 100, 100), ground_item(2, 101, 101)]

    expect(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 -> items end)
    reject(&PartyManager.get/1)
    stub(ItemManagement, :get_item_by_id, fn 501 -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _inventory, _stats, @item_def, 1 -> :ok end)

    stub(InventoryOps, :add, fn 10, inventory, _stats, @item_def, 1, %{identify: 1} ->
      index = map_size(inventory)
      persisted = Map.put(inventory, index, :item)
      {:ok, persisted, {:added, index, :item}}
    end)

    for item <- items do
      ground_id = item.id

      expect(Coordinator, :claim_item, fn "prontera",
                                          ^ground_id,
                                          10,
                                          %{party_id: 0, pickup_share: false} ->
        {:ok, item}
      end)
    end

    assert {:ok, collected} = BsGreed.cast(caster(), :self, 1, BsGreed.definition())
    assert map_size(collected.inventory) == 2
    assert collected.cart == %{}
    assert length(collected.pending_inventory_notify) == 2
  end

  test "skips an item claimed after enumeration without delivering it twice" do
    stolen = ground_item(1, 100, 100)

    expect(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 -> [stolen] end)
    stub(ItemManagement, :get_item_by_id, fn 501 -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _inventory, _stats, @item_def, 1 -> :ok end)

    expect(Coordinator, :claim_item, fn "prontera", 1, 10, %{party_id: 0, pickup_share: false} ->
      {:error, :gone}
    end)

    reject(&InventoryManager.handle_give_item/4)

    assert {:ok, unchanged} = BsGreed.cast(caster(), :self, 1, BsGreed.definition())
    assert unchanged.inventory == %{}
  end

  test "a stale party membership degrades to the solo context" do
    item = ground_item(1, 100, 100)

    expect(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 -> [item] end)
    expect(PartyManager, :get, fn 77 -> {:error, :not_found} end)
    stub(ItemManagement, :get_item_by_id, fn 501 -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _inventory, _stats, @item_def, 1 -> :ok end)

    stub(InventoryOps, :add, fn 10, inventory, _stats, @item_def, 1, %{identify: 1} ->
      index = map_size(inventory)
      {:ok, Map.put(inventory, index, :item), {:added, index, :item}}
    end)

    expect(Coordinator, :claim_item, fn "prontera", 1, 10, %{party_id: 0, pickup_share: false} ->
      {:ok, item}
    end)

    assert {:ok, collected} = BsGreed.cast(caster(party_id: 77), :self, 1, BsGreed.definition())
    assert map_size(collected.inventory) == 1
  end

  test "collects owned and public items while skipping protected items" do
    owned = ground_item(1, 100, 100)
    protected = ground_item(2, 101, 100)
    public = ground_item(3, 102, 100)
    party_ctx = %{party_id: 77, pickup_share: true}

    expect(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 ->
      [owned, protected, public]
    end)

    GroundItemStore.put("prontera", protected)
    expect(PartyManager, :get, fn 77 -> {:ok, party_state(77)} end)
    stub(ItemManagement, :get_item_by_id, fn 501 -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _inventory, _stats, @item_def, 1 -> :ok end)

    stub(InventoryOps, :add, fn 10, inventory, _stats, @item_def, 1, %{identify: 1} ->
      index = map_size(inventory)
      {:ok, Map.put(inventory, index, :item), {:added, index, :item}}
    end)

    expect(Coordinator, :claim_item, fn "prontera", 1, 10, ^party_ctx -> {:ok, owned} end)
    expect(Coordinator, :claim_item, fn "prontera", 2, 10, ^party_ctx -> {:error, :protected} end)
    expect(Coordinator, :claim_item, fn "prontera", 3, 10, ^party_ctx -> {:ok, public} end)

    assert {:ok, collected} = BsGreed.cast(caster(party_id: 77), :self, 1, BsGreed.definition())
    assert map_size(collected.inventory) == 2
    assert {:ok, ^protected} = GroundItemStore.get("prontera", protected.id)
  end

  test "sweeps at exactly Manhattan distance 2 and leaves distance 3 on the ground" do
    in_range = ground_item(1, 101, 101)
    out_of_range = ground_item(2, 102, 101)

    assert manhattan(in_range) == 2
    assert manhattan(out_of_range) == 3

    expect(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 ->
      GroundItemStore.query_in_range("prontera", 100, 100, 2)
    end)

    GroundItemStore.put("prontera", in_range)
    GroundItemStore.put("prontera", out_of_range)

    stub(ItemManagement, :get_item_by_id, fn 501 -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _inventory, _stats, @item_def, 1 -> :ok end)

    stub(InventoryOps, :add, fn 10, inventory, _stats, @item_def, 1, %{identify: 1} ->
      index = map_size(inventory)
      {:ok, Map.put(inventory, index, :item), {:added, index, :item}}
    end)

    expect(Coordinator, :claim_item, fn "prontera", 1, 10, %{party_id: 0, pickup_share: false} ->
      {:ok, in_range}
    end)

    assert {:ok, collected} = BsGreed.cast(caster(), :self, 1, BsGreed.definition())
    assert map_size(collected.inventory) == 1
  end

  test "re-drops a claimed item when the add fails" do
    first = ground_item(1, 100, 100)

    second =
      ground_item(2, 101, 100)
      |> Map.put(:owners, {10, 20, 30})
      |> Map.put(:unlock_at, {100, 200, 300})

    expect(GroundItemStore, :query_in_range, fn "prontera", 100, 100, 2 -> [first, second] end)
    stub(ItemManagement, :get_item_by_id, fn 501 -> {:ok, @item_def} end)
    stub(InventoryOps, :can_add, fn _inventory, _stats, @item_def, 1 -> :ok end)

    expect(Coordinator, :claim_item, fn "prontera", 1, 10, %{party_id: 0, pickup_share: false} ->
      {:ok, first}
    end)

    expect(Coordinator, :claim_item, fn "prontera", 2, 10, %{party_id: 0, pickup_share: false} ->
      {:ok, second}
    end)

    expect(InventoryManager, :handle_give_item, 2, fn @item_def, 1, state, true ->
      case state.inventory do
        %{} = inventory when map_size(inventory) == 0 ->
          {:ok, %{state | inventory: %{0 => :item}}}

        _full ->
          {:error, :inventory_full, state}
      end
    end)

    expect(Coordinator, :drop_items, fn "prontera",
                                        [{501, 1, 101, 100, true}],
                                        101,
                                        100,
                                        ownership: {{10, 20, 30}, {100, 200, 300}} ->
      :ok
    end)

    assert {:ok, collected} = BsGreed.cast(caster(), :self, 1, BsGreed.definition())
    assert collected.inventory == %{0 => :item}
  end

  defp caster(opts \\ []) do
    %PlayerState{
      character_id: 10,
      map_name: "prontera",
      x: 100,
      y: 100,
      party_id: Keyword.get(opts, :party_id, 0),
      inventory: %{},
      stats: %{},
      pending_inventory_notify: []
    }
  end

  defp party_state(party_id) do
    %PartyState{
      party_id: party_id,
      name: "Test Party",
      leader_char_id: 10,
      exp_share: false,
      item_pickup_share: true
    }
  end

  defp manhattan(%GroundItem{x: x, y: y}), do: abs(x - 100) + abs(y - 100)

  defp ground_item(id, x, y) do
    %GroundItem{
      id: id,
      nameid: 501,
      amount: 1,
      x: x,
      y: y,
      sub_x: 3,
      sub_y: 3,
      identified: true,
      dropped_at: 0
    }
  end
end
