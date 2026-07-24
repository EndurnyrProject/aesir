defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtRemovetrapTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
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

  test "has the canonical active ground-target definition" do
    assert {:ok, definition} = Catalog.by_id(124)
    assert definition == HtRemovetrap.definition()
    assert definition.name == :ht_removetrap
    assert definition.display_name == "Remove Trap"
    assert definition.max_level == 1
    assert definition.target_type == :ground
    assert definition.damage_type == :no_damage
    assert definition.range == 2
    assert definition.sp_cost == [5]
    assert {:ok, HtRemovetrap} = Catalog.active_module_for(:ht_removetrap)
    assert :ground not in HtRemovetrap.__skill_capabilities__()
  end

  test "preflights capacity for one trap item" do
    definition = HtRemovetrap.definition()
    caster = caster()

    expect(ItemManagement, :get_item_by_id, fn 1065 -> {:ok, @trap_item} end)

    expect(InventoryOps, :can_add, fn inventory, stats, @trap_item, 1 ->
      assert inventory == caster.inventory
      assert stats == caster.stats
      {:error, :inventory_full}
    end)

    assert {:error, :inventory_full} =
             HtRemovetrap.validate(caster, {:ground, 51, 50}, 1, definition)
  end

  test "atomically claims the caster's trap and adds exactly the returned item" do
    definition = HtRemovetrap.definition()
    caster = caster()
    persisted = %{0 => %{nameid: 1065, amount: 1}}
    change = {:added, 0, %{nameid: 1065, amount: 1}}

    expect(ItemManagement, :get_item_by_id, fn 1065 -> {:ok, @trap_item} end)
    expect(InventoryOps, :can_add, fn %{}, %Stats{}, @trap_item, 1 -> :ok end)

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

  test "a failed preflight never claims the trap" do
    definition = HtRemovetrap.definition()
    caster = caster()

    expect(ItemManagement, :get_item_by_id, fn 1065 -> {:ok, @trap_item} end)

    expect(InventoryOps, :can_add, fn %{}, %Stats{}, @trap_item, 1 ->
      {:error, :inventory_full}
    end)

    reject(&Manager.reclaim_trap/4)
    reject(&InventoryOps.add/5)

    assert {:error, :inventory_full} =
             HtRemovetrap.cast(caster, {:ground, 51, 50}, 1, definition)
  end

  test "a persistence failure after the claim returns the error without staging a reward" do
    definition = HtRemovetrap.definition()
    caster = caster()

    expect(ItemManagement, :get_item_by_id, fn 1065 -> {:ok, @trap_item} end)
    expect(InventoryOps, :can_add, fn %{}, %Stats{}, @trap_item, 1 -> :ok end)

    expect(Manager, :reclaim_trap, fn {:player, 1000}, "prontera", 51, 50 ->
      {:ok, %{group_id: 44, item_id: 1065}}
    end)

    expect(InventoryOps, :add, fn 1000, %{}, %Stats{}, @trap_item, 1 ->
      {:error, :persistence_failed}
    end)

    assert {:error, :persistence_failed} =
             HtRemovetrap.cast(caster, {:ground, 51, 50}, 1, definition)

    assert caster.inventory == %{}
    assert caster.pending_inventory_notify == []
  end

  test "missing, foreign, spent, and unsupported traps grant no item" do
    definition = HtRemovetrap.definition()
    caster = caster()

    stub(ItemManagement, :get_item_by_id, fn 1065 -> {:ok, @trap_item} end)
    stub(InventoryOps, :can_add, fn %{}, %Stats{}, @trap_item, 1 -> :ok end)

    errors = %{51 => :not_found, 52 => :not_owner, 53 => :already_spent, 54 => :unsupported_trap}

    stub(Manager, :reclaim_trap, fn {:player, 1000}, "prontera", x, 50 ->
      {:error, Map.fetch!(errors, x)}
    end)

    reject(&InventoryOps.add/5)

    Enum.each(errors, fn {x, reason} ->
      assert {:error, ^reason} =
               HtRemovetrap.cast(caster, {:ground, x, 50}, 1, definition)
    end)
  end
end
