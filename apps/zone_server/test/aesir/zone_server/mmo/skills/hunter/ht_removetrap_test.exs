defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtRemovetrapTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtRemovetrap
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :verify_on_exit!

  setup do
    Mimic.copy(Manager)
    :ok
  end

  @trap_item %ItemDefinition{
    id: 1065,
    aegis_name: "Booby_Trap",
    name: "Trap",
    weight: 10
  }

  defp caster(attrs \\ %{}) do
    struct!(
      PlayerState,
      Map.merge(
        %{
          character_id: 1000,
          map_name: "prontera",
          x: 50,
          y: 50,
          inventory: %{},
          stats: %Stats{},
          pending_inventory_notify: []
        },
        attrs
      )
    )
  end

  test "validation no longer preflights capacity" do
    definition = HtRemovetrap.definition()
    caster = caster()

    reject(&ItemManagement.get_item_by_id/1)
    reject(&InventoryOps.can_add/4)

    assert :ok = HtRemovetrap.validate(caster, {:ground, 51, 50}, 1, definition)
  end

  test "atomically claims the caster's trap and adds exactly the returned item" do
    definition = HtRemovetrap.definition()
    caster = caster()
    persisted = %{0 => %{nameid: 1065, amount: 1}}
    change = {:added, 0, %{nameid: 1065, amount: 1}}

    expect(ItemManagement, :get_item_by_id, fn 1065 -> {:ok, @trap_item} end)

    expect(Manager, :reclaim_trap, fn {:player, 1000}, "prontera", 51, 50 ->
      {:ok, %{group_id: 44, item_id: 1065}}
    end)

    expect(InventoryOps, :add, fn 1000, %{}, %Stats{}, @trap_item, 1 ->
      {:ok, persisted, change}
    end)

    assert {:ok, updated} = HtRemovetrap.cast(caster, {:ground, 51, 50}, 1, definition)
    assert updated.inventory == persisted
    assert updated.pending_inventory_notify == [change]
  end

  test "an item that does not fit still completes the removal" do
    definition = HtRemovetrap.definition()
    caster = caster()

    expect(ItemManagement, :get_item_by_id, fn 1065 -> {:ok, @trap_item} end)

    expect(Manager, :reclaim_trap, fn {:player, 1000}, "prontera", 51, 50 ->
      {:ok, %{group_id: 44, item_id: 1065}}
    end)

    expect(InventoryOps, :add, fn 1000, %{}, %Stats{}, @trap_item, 1 ->
      {:error, :inventory_full}
    end)

    assert {:ok, updated} = HtRemovetrap.cast(caster, {:ground, 51, 50}, 1, definition)
    assert updated.inventory == caster.inventory
    assert updated.pending_item_add_failures == [:inventory_full]
  end

  test "a persistence failure after the claim still completes the removal" do
    definition = HtRemovetrap.definition()
    caster = caster()

    expect(ItemManagement, :get_item_by_id, fn 1065 -> {:ok, @trap_item} end)

    expect(Manager, :reclaim_trap, fn {:player, 1000}, "prontera", 51, 50 ->
      {:ok, %{group_id: 44, item_id: 1065}}
    end)

    expect(InventoryOps, :add, fn 1000, %{}, %Stats{}, @trap_item, 1 ->
      {:error, :persistence_failed}
    end)

    assert {:ok, ^caster} = HtRemovetrap.cast(caster, {:ground, 51, 50}, 1, definition)

    assert caster.inventory == %{}
    assert caster.pending_inventory_notify == []
  end

  test "missing, foreign, and non-trap targets are reported failures" do
    definition = HtRemovetrap.definition()
    caster = caster()

    reject(&ItemManagement.get_item_by_id/1)
    reject(&InventoryOps.add/5)

    errors = %{51 => :not_found, 52 => :not_owner, 54 => :unsupported_trap}

    stub(Manager, :reclaim_trap, fn {:player, 1000}, "prontera", x, 50 ->
      {:error, Map.fetch!(errors, x)}
    end)

    Enum.each(errors, fn {x, reason} ->
      assert {:failed, ^caster, ^reason} =
               HtRemovetrap.cast(caster, {:ground, x, 50}, 1, definition)
    end)
  end

  test "a used trap is removed without returning an item" do
    definition = HtRemovetrap.definition()
    caster = caster()

    reject(&ItemManagement.get_item_by_id/1)
    reject(&InventoryOps.add/5)

    stub(Manager, :reclaim_trap, fn {:player, 1000}, "prontera", 51, 50 ->
      {:ok, %{group_id: 44, item_id: nil}}
    end)

    assert {:ok, ^caster} = HtRemovetrap.cast(caster, {:ground, 51, 50}, 1, definition)
  end
end
