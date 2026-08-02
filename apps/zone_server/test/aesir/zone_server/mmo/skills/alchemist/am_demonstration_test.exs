defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmDemonstrationTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmDemonstration
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster_id 1_000
  @map_name "prontera"
  @center {150, 150}

  defp group(level) do
    %Group{
      group_id: 1,
      skill_id: 229,
      skill_name: :am_demonstration,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: [],
      interval: 500,
      state: %{}
    }
  end

  defp caster_with_bottle do
    %PlayerState{
      character_id: @caster_id,
      map_name: @map_name,
      x: 150,
      y: 150,
      inventory: %{0 => %InventoryItem{nameid: 7135, amount: 1, equip: 0}},
      pending_inventory_persist: [],
      stats: %{current_state: %{sp: 100}}
    }
  end

  describe "skill data and placement" do
    test "defines a five-level physical Fire ground skill that costs one Fire Bottle" do
      assert {:ok, definition} = Catalog.by_id(229)
      assert definition.name == :am_demonstration
      assert definition.max_level == 5
      assert definition.target_type == :ground
      assert definition.damage_kind == :weapon
      assert definition.element == :fire
      assert definition.hit_interval == 500
      assert definition.sp_cost == List.duplicate(10, 5)
      assert definition.item_cost == [%{id: 7135, amount: 1}]
      assert definition.unit_duration == [45_000, 50_000, 55_000, 60_000, 65_000]
    end

    test "places the filled 3x3 area for the level duration" do
      assert {:ok, placement} = AmDemonstration.on_place(group(3))

      assert Enum.sort(placement.cells) ==
               Enum.sort(for(x <- 149..151, y <- 149..151, do: {x, y}))

      assert placement.interval == 500
      assert placement.duration == 55_000
    end

    test "consumes one Fire Bottle after a successful placement" do
      caster = caster_with_bottle()
      stub(Storage, :get_groups_at_cell, fn _map_name, _x, _y -> [] end)
      stub(Unit, :place, fn ^caster, :am_demonstration, 3, @center -> {:ok, group(3)} end)

      assert {:ok, updated} = Interpreter.complete_cast(caster, 229, 3, {:ground, 150, 150})
      assert updated.inventory == %{}
      assert [_] = updated.pending_inventory_persist
    end

    test "expires when its level duration elapses" do
      manager =
        start_supervised!(
          {Manager,
           name: nil,
           schedule_tick: fn _pid, _interval -> :ok end,
           unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
        )

      allow(Catalog, self(), manager)

      expired_group = %{
        group(3)
        | cells: [@center],
          created_at: 0,
          next_tick_at: 100_000,
          expires_at: 55_000
      }

      assert :ok = Storage.insert(expired_group)
      assert :ok = Manager.tick(manager, 55_000)
      assert Storage.get(expired_group.group_id) == nil
    end
  end

  describe "NoReiteration" do
    test "rejects a target whose 3x3 area overlaps an existing Demonstration" do
      existing = %{group(1) | center: {151, 151}, cells: [{151, 151}]}

      stub(Storage, :get_groups_at_cell, fn
        @map_name, 151, 151 -> [existing]
        _map_name, _x, _y -> []
      end)

      assert {:error, :skill_unit_overlap} =
               AmDemonstration.validate(%{map_name: @map_name}, {:ground, 150, 150}, 1, %{})
    end

    test "rejects an overlap before consuming the Fire Bottle" do
      caster = caster_with_bottle()
      existing = %{group(1) | cells: [{150, 150}]}

      stub(Storage, :get_groups_at_cell, fn
        @map_name, 150, 150 -> [existing]
        _map_name, _x, _y -> []
      end)

      reject(&Unit.place/4)

      assert {:error, :skill_unit_overlap} =
               Interpreter.complete_cast(caster, 229, 3, {:ground, 150, 150})

      assert caster.inventory == %{0 => %InventoryItem{nameid: 7135, amount: 1, equip: 0}}
    end

    test "allows overlap with other ground skills" do
      existing = %{group(1) | skill_id: 18, skill_name: :mg_firewall, cells: [{150, 150}]}

      stub(Storage, :get_groups_at_cell, fn
        @map_name, 150, 150 -> [existing]
        _map_name, _x, _y -> []
      end)

      assert :ok =
               AmDemonstration.validate(%{map_name: @map_name}, {:ground, 150, 150}, 1, %{})
    end
  end

  describe "on_interval/2" do
    test "applies Fire physical weapon damage and rolls weapon break only after a confirmed hit" do
      test_pid = self()
      caster = %PlayerState{character_id: @caster_id}

      stub(UnitRegistry, :get_unit, fn :player, @caster_id ->
        {:ok, {PlayerState, caster, self()}}
      end)

      stub(Combat, :splash_targets, fn @map_name, @center, 1, @caster_id -> [{:player, 2_000}] end)

      stub(Combat, :execute_skill_attack, fn ^caster,
                                             2_000,
                                             skill_id: 229,
                                             skill_level: 3,
                                             skill_ratio: 160,
                                             element: :fire,
                                             skip_crit: true,
                                             skip_range: true,
                                             report_hit: true ->
        {:ok, %{hit?: true, damage: 1, target_survives?: true}}
      end)

      victim = %PlayerState{character_id: 2_000}

      stub(UnitRegistry, :get_unit, fn
        :player, @caster_id -> {:ok, {PlayerState, caster, self()}}
        :player, 2_000 -> {:ok, {PlayerState, victim, self()}}
      end)

      stub(EquipBreak, :resolve_slot, fn 900, {:player, 2_000, nil}, :weapon ->
        send(test_pid, :break_rolled)
        []
      end)

      assert {:ok, %Group{}} = AmDemonstration.on_interval(group(3), 500)
      assert_received :break_rolled
    end

    test "does not roll weapon break when the physical tick misses" do
      caster = %PlayerState{character_id: @caster_id}

      stub(UnitRegistry, :get_unit, fn :player, @caster_id ->
        {:ok, {PlayerState, caster, self()}}
      end)

      stub(Combat, :splash_targets, fn @map_name, @center, 1, @caster_id -> [{:mob, 2_000}] end)

      stub(Combat, :execute_skill_attack, fn ^caster, 2_000, _opts ->
        {:ok, %{hit?: false, damage: 0, target_survives?: true}}
      end)

      reject(&EquipBreak.resolve_slot/4)

      assert {:ok, %Group{}} = AmDemonstration.on_interval(group(3), 500)
    end

    test "expires gracefully when the caster is gone" do
      stub(UnitRegistry, :get_unit, fn :player, @caster_id -> {:error, :not_found} end)
      reject(&Combat.splash_targets/4)

      assert {:expire, %Group{}} = AmDemonstration.on_interval(group(3), 500)
    end
  end
end
