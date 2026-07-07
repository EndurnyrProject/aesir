defmodule Aesir.ZoneServer.Mmo.Skills.TfPickstoneTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.TfPickstone
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps

  setup :verify_on_exit!

  @caster %{
    character_id: 1000,
    inventory: %{},
    stats: %{},
    pending_inventory_notify: []
  }

  test "Catalog.by_id/1 resolves TF_PICKSTONE" do
    assert {:ok, definition} = Catalog.by_id(151)
    assert definition.name == :tf_pickstone
    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.sp_cost == [2]
    assert definition.fixed_cast_time == [500]
  end

  test "cast/4 grants 1x Stone (id 7049) and stages the change for client notify" do
    {:ok, definition} = Catalog.by_id(151)
    item_def = %{id: 7049, weight: 10}
    new_inventory = %{0 => %{nameid: 7049, amount: 1}}
    change = {:added, 0, %{nameid: 7049, amount: 1}}

    expect(ItemManagement, :get_item_by_id, fn 7049 -> {:ok, item_def} end)

    expect(InventoryOps, :add, fn 1000, _inventory, _stats, ^item_def, 1 ->
      {:ok, new_inventory, change}
    end)

    assert {:ok, updated} = TfPickstone.cast(@caster, :self, 1, definition)
    assert updated.inventory == new_inventory
    assert updated.pending_inventory_notify == [change]
  end

  test "propagates {:error, :overweight} when carry limit is exceeded" do
    {:ok, definition} = Catalog.by_id(151)
    item_def = %{id: 7049, weight: 10}

    expect(ItemManagement, :get_item_by_id, fn 7049 -> {:ok, item_def} end)

    expect(InventoryOps, :add, fn 1000, _inventory, _stats, ^item_def, 1 ->
      {:error, :overweight}
    end)

    assert {:error, :overweight} = TfPickstone.cast(@caster, :self, 1, definition)
  end
end
