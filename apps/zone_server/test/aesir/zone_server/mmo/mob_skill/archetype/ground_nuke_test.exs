defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundNukeTest do
  @moduledoc """
  Coverage for the mob ground-nuke archetype: `apply/4` builds and stores a
  mob-cast ground `Group` directly (no player `Skill.Unit.place/4`), the central
  `Manager` dispatches the group's interval to `GroundNuke.on_interval/2`
  (mob-caster dispatch, not the player catalog), each tick damages player
  occupants of the footprint, and the group expires after its duration.
  """

  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.GroundSkill
  alias Aesir.Net.SkillUnitSnapshot
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundNuke
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    manager =
      start_supervised!(
        {Manager,
         name: nil,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
      )

    Process.put({Manager, :server}, manager)
    allow(Broadcast, self(), manager)
    %{manager: manager}
  end

  @caster_id 5001
  @target_id 42
  @map "prontera"
  @skill_id 83
  @level 5
  @center {120, 120}

  defp build_caster do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_CASTER",
      name: "Test Caster",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(@caster_id, mob_data, spawn_ref, @map, 100, 100)
  end

  defp stub_walkable_map do
    map = MapData.new(@map, 250, 250)
    :ets.insert(EtsTable.table_for(:map_cache), {@map, map})
  end

  defp params do
    %{skill_id: @skill_id, skill: "WZ_METEOR", element: :fire, area: :around}
  end

  defp place! do
    test_pid = self()

    stub(Broadcast, :to_in_range, fn @map, _x, _y, _range, packet ->
      send(test_pid, {:packet, packet})
      :ok
    end)

    assert :ok = GroundNuke.apply(build_caster(), {:ground, 120, 120, :around}, params(), @level)

    assert [%Group{} = group] = Storage.all()
    group
  end

  defp allow_tick_mocks(manager) do
    allow(Combat, self(), manager)
    allow(SpatialIndex, self(), manager)
  end

  describe "apply/4" do
    test "inserts a mob-cast group with the area footprint and broadcasts GroundSkill" do
      stub_walkable_map()

      group = place!()

      assert group.caster_type == :mob
      assert group.caster_id == @caster_id
      assert group.skill_id == @skill_id
      assert group.level == @level
      assert group.map_name == @map
      assert group.center == @center
      assert length(group.cells) == 25
      assert @center in group.cells
      assert group.state.element == :fire
      assert group.expires_at > group.next_tick_at

      assert_received {:packet,
                       %GroundSkill{
                         skill_id: @skill_id,
                         src_id: @caster_id,
                         level: @level,
                         x: 120,
                         y: 120
                       }}
    end

    test "publishes and snapshots stable cells for a mob ground nuke" do
      stub_walkable_map()
      group = place!()

      assert %Group{visible?: true, created_at: created_at, cell_ids: cell_ids} = group
      assert is_integer(created_at)
      assert length(cell_ids) == length(group.cells)
      assert_receive {:packet, %SkillUnitSpawn{group: %{group_id: group_id, cells: spawn_cells}}}
      assert group_id == group.group_id
      assert Enum.sort(Enum.map(spawn_cells, & &1.cell_id)) == Enum.sort(cell_ids)

      assert %SkillUnitSnapshot{groups: [%{group_id: ^group_id, cells: snapshot_cells}]} =
               Manager.snapshot("prontera", 123)

      assert Enum.sort(Enum.map(snapshot_cells, & &1.cell_id)) == Enum.sort(cell_ids)
    end

    test "clamps the footprint to walkable cells" do
      stub_walkable_map()

      for {x, y} <- Layout.square(@center, 2), {x, y} != @center do
        :ok = Cell.put(@map, x, y, :test_blocker, x * 1_000 + y + 1, blocks_movement: true)
      end

      group = place!()

      assert group.cells == [@center]
    end

    test "returns an error when the map is not cached" do
      :ets.delete(EtsTable.table_for(:map_cache), @map)

      assert {:error, :unknown_map} =
               GroundNuke.apply(build_caster(), {:ground, 120, 120, :around}, params(), @level)

      assert [] == Storage.all()
    end

    test "returns an error when no footprint cell is walkable" do
      stub_walkable_map()

      for {x, y} <- Layout.square(@center, 2) do
        :ok = Cell.put(@map, x, y, :test_blocker, x * 1_000 + y + 1, blocks_movement: true)
      end

      assert {:error, :no_walkable_cells} =
               GroundNuke.apply(build_caster(), {:ground, 120, 120, :around}, params(), @level)

      assert [] == Storage.all()
    end

    test "returns an error for a non-ground target" do
      assert {:error, :invalid_target} =
               GroundNuke.apply(build_caster(), {:unit, :player, @target_id}, params(), @level)
    end
  end

  describe "ticking through Manager" do
    setup do
      stub_walkable_map()
      %{group: place!()}
    end

    test "a due tick applies magic damage to a player standing on the footprint", %{
      group: group,
      manager: manager
    } do
      test_pid = self()

      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      stub(SpatialIndex, :get_units_in_range, fn :player, @map, 120, 120, _range ->
        [@target_id]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, @target_id ->
        {:ok, {121, 119, @map}}
      end)

      stub(Combat, :apply_skill_unit_damage, fn caster,
                                                :player,
                                                target_id,
                                                @skill_id,
                                                @level,
                                                :fire,
                                                ratio ->
        assert caster.unit_id == @caster_id
        send(test_pid, {:hit, target_id, ratio})
        :ok
      end)

      allow_tick_mocks(manager)
      Manager.tick(manager, group.next_tick_at)

      assert_received {:hit, @target_id, ratio}
      assert is_integer(ratio) and ratio > 0

      rearmed = Storage.get(group.group_id)
      assert rearmed.next_tick_at == group.next_tick_at + group.interval
    end

    test "a player outside the footprint is not hit", %{group: group, manager: manager} do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      stub(SpatialIndex, :get_units_in_range, fn :player, @map, 120, 120, _range ->
        [@target_id]
      end)

      stub(SpatialIndex, :get_unit_position, fn :player, @target_id ->
        {:ok, {130, 130, @map}}
      end)

      reject(&Combat.apply_skill_unit_damage/7)

      allow_tick_mocks(manager)
      Manager.tick(manager, group.next_tick_at)
    end

    test "a despawned caster skips the tick without damage", %{group: group, manager: manager} do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)
      reject(&Combat.apply_skill_unit_damage/7)
      reject(&SpatialIndex.get_units_in_range/5)

      allow_tick_mocks(manager)
      Manager.tick(manager, group.next_tick_at)

      assert Storage.get(group.group_id)
    end

    test "the group is reaped once expires_at passes", %{group: group, manager: manager} do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)

      allow_tick_mocks(manager)
      Manager.tick(manager, group.expires_at)

      assert Storage.get(group.group_id) == nil
    end
  end
end
