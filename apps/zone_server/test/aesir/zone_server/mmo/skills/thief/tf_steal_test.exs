defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfStealTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfSteal
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!

  @target_id 2000
  @jellopy %ItemDefinition{id: 909, aegis_name: "Jellopy", name: "Jellopy", weight: 1}
  @knife %ItemDefinition{id: 1201, aegis_name: "Knife", name: "Knife", type: :weapon, weight: 40}

  defp caster(equipment_modifiers \\ %{}, overrides \\ %{}) do
    PlayerStateFixture.build(
      Map.merge(
        %{
          character_id: 1000,
          map_name: "prontera",
          inventory: %{},
          pending_inventory_notify: [],
          stats: %{modifiers: %{equipment: equipment_modifiers}}
        },
        overrides
      )
    )
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(50)
    definition
  end

  defp registered_mob(pid) do
    stub(UnitRegistry, :unit_type_for, fn @target_id -> {:ok, :mob} end)
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, %{}, pid}} end)
  end

  test "cast/4 resolves the mob pid, calls attempt_steal with the caster's effective DEX, and grants the item" do
    mob_pid = self()
    new_inventory = %{0 => %{nameid: 909, amount: 1}}
    change = {:added, 0, %{nameid: 909, amount: 1}}

    stub(Stats, :get_effective_stat, fn %Stats{}, :dex -> 40 end)
    registered_mob(mob_pid)

    expect(MobSession, :attempt_steal, fn ^mob_pid, %{dex: 40, add_steal_rate: 0}, 6 ->
      {:ok, 909}
    end)

    expect(ItemManagement, :get_item_by_id, fn 909 -> {:ok, @jellopy} end)

    expect(InventoryOps, :add, fn 1000, _inventory, _stats, @jellopy, 1 ->
      {:ok, new_inventory, change}
    end)

    assert {:ok, updated} = TfSteal.cast(caster(), {:unit, @target_id}, 6, definition())
    assert updated.inventory == new_inventory
    assert updated.pending_inventory_notify == [change]
  end

  test "cast/4 settles a rolled steal failure as a paid failure without touching the inventory" do
    caster = caster()

    stub(Stats, :get_effective_stat, fn %Stats{}, :dex -> 40 end)
    registered_mob(self())
    expect(MobSession, :attempt_steal, fn _pid, %{dex: 40}, 1 -> {:error, :miss} end)
    reject(&InventoryOps.add/5)
    reject(&InventoryOps.add/6)

    assert {:failed, ^caster, :miss} =
             TfSteal.cast(caster, {:unit, @target_id}, 1, definition())
  end

  test "cast/4 fails when the mob is not found" do
    stub(UnitRegistry, :unit_type_for, fn @target_id -> {:error, :not_found} end)
    reject(&MobSession.attempt_steal/3)

    assert {:error, :not_found} = TfSteal.cast(caster(), {:unit, @target_id}, 1, definition())
  end

  test "the caster's equipment steal-rate bonus rides the steal request" do
    registered_mob(self())

    expect(MobSession, :attempt_steal, fn _pid, %{add_steal_rate: 15}, 3 -> {:error, :no_drop} end)

    assert {:failed, _caster, :no_drop} =
             TfSteal.cast(caster(%{add_steal_rate: 15}), {:unit, @target_id}, 3, definition())
  end

  test "a stolen weapon arrives unidentified" do
    registered_mob(self())
    stub(MobSession, :attempt_steal, fn _pid, _caster, 1 -> {:ok, 1201} end)
    stub(ItemManagement, :get_item_by_id, fn 1201 -> {:ok, @knife} end)

    expect(InventoryOps, :add, fn 1000, _inventory, _stats, @knife, 1, %{identify: 0} ->
      {:ok, %{}, {:added, 0, %{}}}
    end)

    assert {:ok, _updated} = TfSteal.cast(caster(), {:unit, @target_id}, 1, definition())
  end

  test "an item the caster cannot carry is a paid failure and the inventory is unchanged" do
    caster = caster()
    registered_mob(self())
    stub(MobSession, :attempt_steal, fn _pid, _caster, 1 -> {:ok, 909} end)
    stub(ItemManagement, :get_item_by_id, fn 909 -> {:ok, @jellopy} end)
    stub(InventoryOps, :add, fn _id, _inventory, _stats, _item, 1 -> {:error, :overweight} end)

    assert {:failed, rejected, :item_rejected} =
             TfSteal.cast(caster, {:unit, @target_id}, 1, definition())

    assert rejected.inventory == caster.inventory
    assert rejected.pending_item_add_failures == [:overweight]
  end

  test "a non-monster target is a paid failure that never reaches any monster" do
    caster = caster()
    stub(UnitRegistry, :unit_type_for, fn @target_id -> {:ok, :player} end)
    reject(&UnitRegistry.get_unit/2)
    reject(&MobSession.attempt_steal/3)

    assert {:failed, ^caster, :not_a_monster} =
             TfSteal.cast(caster, {:unit, @target_id}, 1, definition())

    assert {:failed, ^caster, :not_a_monster} =
             TfSteal.cast(caster, {:unit, {:homunculus, @target_id}}, 1, definition())
  end

  test "a non-player caster's Steal does nothing" do
    mob = struct(MobState, instance_id: 7)
    reject(&MobSession.attempt_steal/3)

    assert {:ok, ^mob} = TfSteal.cast(mob, {:unit, @target_id}, 1, definition())
  end

  describe "gank/4" do
    setup do
      stub(Passives, :steal_proc, fn _caster -> 1_000 end)
      :ok
    end

    test "a bow wielder never rolls Gank" do
      stub(Stats, :weapon_type, fn %Equipment{} -> :bow end)
      reject(&MobSession.attempt_steal/3)

      caster = caster()
      assert TfSteal.gank(caster, @target_id, self(), {10, 10}) == caster
    end

    test "steals at the Steal level and shows Steal at the Gank level around the monster" do
      caster = caster(%{}, %{stats: %{progression: %{learned_skills: %{50 => 4, 210 => 7}}}})

      expect(MobSession, :attempt_steal, fn _pid, _caster, 4 -> {:ok, 909} end)
      stub(ItemManagement, :get_item_by_id, fn 909 -> {:ok, @jellopy} end)
      stub(InventoryOps, :add, fn _id, _inventory, _stats, _item, 1 -> {:ok, %{}, :change} end)

      expect(Broadcast, :to_in_range, fn "prontera", 10, 11, _range, packet ->
        assert %SkillEffect{skill_id: 50, level: 7, target_id: @target_id, src_id: 1000} =
                 packet

        :ok
      end)

      assert %{pending_inventory_notify: [:change]} =
               TfSteal.gank(caster, @target_id, self(), {10, 11})
    end

    test "a failed theft reports Gank's failure to the caster" do
      stub(MobSession, :attempt_steal, fn _pid, _caster, _level -> {:error, :miss} end)

      expect(Broadcast, :to_player, fn 1000, %SkillCastFailed{skill_id: 210} -> :ok end)
      reject(&Broadcast.to_in_range/5)
      reject(&MobSession.skill_event/4)

      caster = caster()
      assert TfSteal.gank(caster, @target_id, self(), {10, 10}) == caster
    end
  end
end
