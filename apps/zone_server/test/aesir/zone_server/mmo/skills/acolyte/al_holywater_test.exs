defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolywaterTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
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
    @tag game_mode: :renewal
    test "renewal splits the cast into variable and fixed parts" do
      assert {:ok, defn} = Catalog.by_id(31)
      assert defn.max_level == 1
      assert defn.target_type == :self
      assert defn.item_cost == []
      assert defn.sp_cost == [10]
      assert defn.cast_time == [800]
      assert defn.fixed_cast_time == [200]
      assert defn.after_cast_delay == [500]
    end

    @tag game_mode: :pre_renewal
    test "by_id/1 resolves the classic one-second cast with no fixed component" do
      assert {:ok, defn} = Catalog.by_id(31)
      assert defn.sp_cost == [10]
      assert defn.cast_time == [1_000]
      assert defn.fixed_cast_time == []
      assert defn.after_cast_delay == [500]
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

  describe "begin_attempt/4" do
    test "starts only while the caster holds an Empty Bottle" do
      {:ok, definition} = Catalog.by_id(31)

      assert {:error, :no_empty_bottle} =
               AlHolywater.begin_attempt(@caster, :self, 1, definition)

      holder = %{@caster | inventory: %{0 => %InventoryItem{nameid: 713, amount: 1}}}
      assert {:ok, ^holder} = AlHolywater.begin_attempt(holder, :self, 1, definition)
    end
  end

  describe "cast/4" do
    defp holder(bottles, extra \\ %{}) do
      inventory = Map.merge(%{0 => %InventoryItem{nameid: 713, amount: bottles}}, extra)
      Map.merge(@caster, %{inventory: inventory, pending_inventory_persist: []})
    end

    test "consumes one Empty Bottle and adds one Holy Water (id 523)" do
      {:ok, definition} = Catalog.by_id(31)
      item_def = %{id: 523, weight: 30}
      caster = holder(2)
      change = {:added, 1, %{nameid: 523, amount: 1}}

      expect(ItemManagement, :get_item_by_id, fn 523 -> {:ok, item_def} end)

      expect(InventoryOps, :add, fn 1000, inventory, _stats, ^item_def, 1 ->
        assert %{0 => %InventoryItem{nameid: 713, amount: 1}} = inventory
        {:ok, Map.put(inventory, 1, %{nameid: 523, amount: 1}), change}
      end)

      assert {:ok, updated} = AlHolywater.cast(caster, :self, 1, definition)
      assert %{0 => %InventoryItem{amount: 1}, 1 => %{nameid: 523}} = updated.inventory
      assert [{_before, _after, {:reduced, 0, 1}}] = updated.pending_inventory_persist
      assert updated.pending_inventory_notify == [change]
    end

    test "a Holy Water that cannot be carried is lost with its bottle" do
      {:ok, definition} = Catalog.by_id(31)
      item_def = %{id: 523, weight: 30}

      expect(ItemManagement, :get_item_by_id, fn 523 -> {:ok, item_def} end)

      expect(InventoryOps, :add, fn 1000, _inventory, _stats, ^item_def, 1 ->
        {:error, :overweight}
      end)

      assert {:ok, updated} = AlHolywater.cast(holder(1), :self, 1, definition)
      assert updated.inventory == %{}
      assert updated.pending_inventory_notify == []
    end

    test "fails after the requirement when no Empty Bottle is left" do
      {:ok, definition} = Catalog.by_id(31)
      reject(&InventoryOps.add/5)

      assert {:failed, @caster, :brew_failed} = AlHolywater.cast(@caster, :self, 1, definition)
    end

    test "fails before taking the bottle when the Holy Water stack is full" do
      {:ok, definition} = Catalog.by_id(31)
      reject(&InventoryOps.add/5)
      caster = holder(1, %{1 => %InventoryItem{nameid: 523, amount: 30_000}})

      assert {:failed, ^caster, :brew_failed} = AlHolywater.cast(caster, :self, 1, definition)
    end
  end
end
