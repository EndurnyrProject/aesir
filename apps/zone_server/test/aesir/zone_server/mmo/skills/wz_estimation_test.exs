defmodule Aesir.ZoneServer.Mmo.Skills.WzEstimationTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Net.EstimationResult
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.EstimationView
  alias Aesir.ZoneServer.Mmo.Skills.WzEstimation
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 100
  @target_id 200

  setup :verify_on_exit!

  describe "definition/0" do
    test "matches Renewal Estimation data" do
      definition = WzEstimation.definition()

      assert definition.id == 93
      assert definition.max_level == 1
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :no_damage
      assert definition.range == 9
      assert definition.sp_cost == [10]
    end

    test "is available to the active skill interpreter through the catalog" do
      assert {:ok, WzEstimation} = Catalog.active_module_for(:wz_estimation)
    end
  end

  describe "EstimationView.result/2" do
    test "builds the exact live monster payload" do
      result = EstimationView.result(@target_id, target())

      assert %EstimationResult{
               target_id: @target_id,
               class_id: 1097,
               level: 42,
               size: 2,
               hp: 1_234,
               def: 88,
               race: 8,
               mdef: 44,
               element: 3,
               water_modifier: 200,
               earth_modifier: 90,
               fire_modifier: 25,
               wind_modifier: 100,
               poison_modifier: 100,
               holy_modifier: 75,
               shadow_modifier: 100,
               ghost_modifier: 100,
               undead_modifier: 75,
               server_tick: server_tick
             } = result

      assert is_integer(server_tick)
    end
  end

  describe "cast/4" do
    test "delivers the result only to the caster session" do
      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:ok, {MobState, target(), self()}}
        :player, @caster_id -> {:ok, {PlayerState, caster(), self()}}
      end)

      assert {:ok, %PlayerState{character_id: @caster_id}} =
               WzEstimation.cast(caster(), {:unit, @target_id}, 1, WzEstimation.definition())

      assert_received {:"$gen_cast", {:send_packet, %EstimationResult{target_id: @target_id}}}
    end

    test "rejects player targets before spending resources" do
      stub(UnitRegistry, :unit_exists?, fn :mob, _target_id -> false end)

      assert {:error, :invalid_target} =
               WzEstimation.validate(caster(), {:unit, @target_id}, 1, WzEstimation.definition())
    end

    test "fails loudly when the target disappears before cast completion" do
      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)

      assert {:error, :target_not_found} =
               WzEstimation.cast(caster(), {:unit, @target_id}, 1, WzEstimation.definition())
    end
  end

  defp caster do
    %PlayerState{character_id: @caster_id}
  end

  defp target do
    mob_data = %MobDefinition{
      id: 1097,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 42,
      hp: 9_999,
      def: 88,
      mdef: 44,
      stats: %{},
      attack_range: 1,
      size: :large,
      race: :demon,
      element: {:fire, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400
    }

    %MobState{
      instance_id: @target_id,
      mob_id: mob_data.id,
      mob_data: mob_data,
      spawn_ref: %MobSpawn{
        mob: mob_data.id,
        amount: 1,
        respawn_time: 1_000,
        spawn_area: %MobSpawn.SpawnArea{x: 10, y: 10, xs: 0, ys: 0}
      },
      x: 10,
      y: 10,
      map_name: "prontera",
      hp: 1_234,
      max_hp: mob_data.hp,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end
end
