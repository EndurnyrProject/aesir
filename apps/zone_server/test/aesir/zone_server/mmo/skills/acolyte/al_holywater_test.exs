defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolywaterTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolywater
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps

  setup :verify_on_exit!

  @caster %{
    character_id: 1000,
    map_name: "morocc",
    x: 100,
    y: 100,
    inventory: %{},
    stats: %{},
    pending_inventory_notify: []
  }

  describe "Catalog" do
    test "by_id/1 resolves al_holywater with correct definition" do
      assert {:ok, defn} = Catalog.by_id(31)
      assert defn.name == :al_holywater
      assert defn.display_name == "Aqua Benedicta"
      assert defn.max_level == 1
      assert defn.target_type == :self
      assert defn.sp_cost == [10]
      assert defn.cast_time == [800]
      assert defn.fixed_cast_time == [200]
      assert defn.after_cast_delay == [500]
    end

    test "requires one Empty Bottle (item 713)" do
      assert {:ok, %{item_cost: [%{id: 713, amount: 1}]}} = Catalog.by_id(31)
    end

    test "by_name/1 resolves :al_holywater" do
      assert {:ok, %{id: 31}} = Catalog.by_name(:al_holywater)
    end
  end

  describe "Acolyte skill tree" do
    test "AL_HOLYWATER appears in the Acolyte tree" do
      {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)
      tree = SkillTree.tree_for(acolyte_id)
      assert Map.has_key?(tree, 31)
    end
  end

  describe "validate/4" do
    test "returns :ok when standing on a water cell" do
      {:ok, definition} = Catalog.by_id(31)
      map_data = %{}

      stub(MapCache, :get, fn "morocc" -> {:ok, map_data} end)
      stub(MapData, :check_cell, fn ^map_data, 100, 100, :chk_water -> true end)

      assert :ok = AlHolywater.validate(@caster, :self, 1, definition)
    end

    test "returns {:error, :not_on_water} when not standing on a water cell" do
      {:ok, definition} = Catalog.by_id(31)
      map_data = %{}

      stub(MapCache, :get, fn "morocc" -> {:ok, map_data} end)
      stub(MapData, :check_cell, fn ^map_data, 100, 100, :chk_water -> false end)

      assert {:error, :not_on_water} = AlHolywater.validate(@caster, :self, 1, definition)
    end

    test "returns {:error, :not_on_water} when map is not found" do
      {:ok, definition} = Catalog.by_id(31)

      stub(MapCache, :get, fn "morocc" -> {:error, :not_found} end)

      assert {:error, :not_on_water} = AlHolywater.validate(@caster, :self, 1, definition)
    end
  end

  describe "cast/4" do
    test "adds Holy Water (id 523) to inventory and stages the change for client notify" do
      {:ok, definition} = Catalog.by_id(31)
      item_def = %{id: 523, weight: 30}
      new_inventory = %{0 => %{nameid: 523, amount: 1}}
      change = {:added, 0, %{nameid: 523, amount: 1}}

      expect(ItemManagement, :get_item_by_id, fn 523 -> {:ok, item_def} end)

      expect(InventoryOps, :add, fn 1000, _inventory, _stats, ^item_def, 1 ->
        {:ok, new_inventory, change}
      end)

      assert {:ok, updated} = AlHolywater.cast(@caster, :self, 1, definition)
      assert updated.inventory == new_inventory
      assert updated.pending_inventory_notify == [change]
    end

    test "propagates {:error, :overweight} when carry limit is exceeded" do
      {:ok, definition} = Catalog.by_id(31)
      item_def = %{id: 523, weight: 30}

      expect(ItemManagement, :get_item_by_id, fn 523 -> {:ok, item_def} end)

      expect(InventoryOps, :add, fn 1000, _inventory, _stats, ^item_def, 1 ->
        {:error, :overweight}
      end)

      assert {:error, :overweight} = AlHolywater.cast(@caster, :self, 1, definition)
    end
  end
end
