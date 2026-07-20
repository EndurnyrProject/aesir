defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundFieldTest do
  @moduledoc """
  Coverage for the mob ground-field archetype: a mob cast places the *player*
  skill's own ground group (`SA_LANDPROTECTOR` -> `Skills.SaLandprotector`)
  through the shared `Skill.Unit.place_group/2` path, so the field it drops is
  the real one — same `on_place/1` footprint, same suppression, same
  `Manager` bookkeeping — only with `caster_type: :mob`.
  """

  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundField
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  @caster_id 5001
  @target_id 42
  @map "prontera"
  @lp_skill_id 288

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

    map = MapData.new(@map, 250, 250)
    :ets.insert(EtsTable.table_for(:map_cache), {@map, map})

    test_pid = self()

    stub(Broadcast, :to_in_range, fn @map, _x, _y, _range, packet ->
      send(test_pid, {:packet, packet})
      :ok
    end)

    %{manager: manager}
  end

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

  defp params,
    do: %{skill_id: @lp_skill_id, skill: "SA_LANDPROTECTOR", skill_name: :sa_landprotector}

  defp index_player(id, action_state \\ :idle, hp \\ 100) do
    UnitRegistry.register_unit(
      :player,
      id,
      PlayerState,
      %PlayerState{
        character_id: id,
        action_state: action_state,
        stats: %{current_state: %{hp: hp}}
      },
      self()
    )
  end

  describe "apply/4" do
    test "a mob cast at a ground cell places the real Land Protector field" do
      assert :ok = GroundField.apply(build_caster(), {:ground, 102, 102, :around}, params(), 1)

      assert [%Group{} = group] = Storage.all()
      assert group.caster_type == :mob
      assert group.caster_id == @caster_id
      assert group.skill_name == :sa_landprotector
      assert group.skill_id == @lp_skill_id
      assert group.level == 1
      assert group.map_name == @map
      assert group.center == {102, 102}
      assert Group.land_protector?(group)
      # SaLandprotector.on_place/1: layout radius 3 at level 1 -> a 7x7 field.
      assert length(group.cells) == 49
      # SaLandprotector.schedule/2 makes the field tickless.
      assert group.next_tick_at == nil
      assert group.visible?

      assert_received {:packet, %GroundSkill{skill_id: @lp_skill_id, src_id: @caster_id, x: 102}}
    end

    test "a unit-target row places the field on the target's cell" do
      :ok = index_player(@target_id)

      stub(SpatialIndex, :get_unit_position, fn :player, @target_id -> {:ok, {104, 101, @map}} end)

      assert :ok = GroundField.apply(build_caster(), {:unit, :player, @target_id}, params(), 1)

      assert [%Group{center: {104, 101}, caster_type: :mob}] = Storage.all()
    end

    test "a unit-target row rejects an indexed corpse" do
      :ok = index_player(@target_id, :dead, 0)

      stub(SpatialIndex, :get_unit_position, fn :player, @target_id -> {:ok, {104, 101, @map}} end)

      assert {:error, :no_target} =
               GroundField.apply(build_caster(), {:unit, :player, @target_id}, params(), 1)

      assert [] == Storage.all()
    end

    test "a self-target row places the field on the caster's own cell" do
      assert :ok = GroundField.apply(build_caster(), {:unit, :mob, @caster_id}, params(), 1)

      assert [%Group{center: {100, 100}, caster_type: :mob}] = Storage.all()
    end

    test "the row's level sizes the field through the skill's own layout table" do
      assert :ok = GroundField.apply(build_caster(), {:ground, 102, 102, :around}, params(), 5)

      assert [%Group{level: 5, cells: cells}] = Storage.all()
      assert length(cells) == 121
    end

    test "a vanished unit target aborts the cast cleanly" do
      stub(SpatialIndex, :get_unit_position, fn :player, @target_id -> {:error, :not_found} end)

      assert {:error, :no_target} =
               GroundField.apply(build_caster(), {:unit, :player, @target_id}, params(), 1)

      assert [] == Storage.all()
    end
  end
end
