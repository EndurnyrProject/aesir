defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfStealTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfSteal
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000

  defp caster do
    %{character_id: 1000, inventory: %{}, stats: %{}, pending_inventory_notify: []}
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(50)
    definition
  end

  test "Catalog.by_id/1 resolves TF_STEAL" do
    assert definition().name == :tf_steal
    assert definition().max_level == 10
    assert definition().target_type == :target_enemy
    assert definition().damage_type == :no_damage
    assert definition().range == 1
    assert definition().sp_cost == List.duplicate(10, 10)
  end

  test "cast/4 resolves the mob pid, calls attempt_steal with the caster's effective DEX, and grants the item" do
    caster = caster()
    mob_pid = self()
    item_def = %{id: 909, weight: 1}
    new_inventory = %{0 => %{nameid: 909, amount: 1}}
    change = {:added, 0, %{nameid: 909, amount: 1}}

    stub(Stats, :get_effective_stat, fn %{}, :dex -> 40 end)
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, %{}, mob_pid}} end)

    expect(MobSession, :attempt_steal, fn ^mob_pid, 40, 6 -> {:ok, 909} end)
    expect(ItemManagement, :get_item_by_id, fn 909 -> {:ok, item_def} end)

    expect(InventoryOps, :add, fn 1000, _inventory, _stats, ^item_def, 1 ->
      {:ok, new_inventory, change}
    end)

    assert {:ok, updated} = TfSteal.cast(caster, {:unit, @target_id}, 6, definition())
    assert updated.inventory == new_inventory
    assert updated.pending_inventory_notify == [change]
  end

  test "cast/4 propagates a steal failure without touching the inventory" do
    caster = caster()
    mob_pid = self()

    stub(Stats, :get_effective_stat, fn %{}, :dex -> 40 end)
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, %{}, mob_pid}} end)
    expect(MobSession, :attempt_steal, fn ^mob_pid, 40, 1 -> {:error, :miss} end)
    reject(&InventoryOps.add/5)

    assert {:error, :miss} = TfSteal.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "cast/4 fails when the mob is not found" do
    caster = caster()

    stub(Stats, :get_effective_stat, fn %{}, :dex -> 40 end)
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
    reject(&MobSession.attempt_steal/3)

    assert {:error, :not_found} = TfSteal.cast(caster, {:unit, @target_id}, 1, definition())
  end
end
