defmodule Aesir.ZoneServer.Mmo.MobManagementTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  setup :setup_ets_tables

  describe "mob data loading" do
    test "loads Poring correctly" do
      assert {:ok, poring} = MobManagement.get_mob_by_id(1002)
      assert %MobDefinition{} = poring
      assert poring.id == 1002
      assert poring.aegis_name == :PORING
      assert poring.name == "Poring"
      assert poring.level == 1
      assert poring.hp == 55
      assert poring.race == :plant
      assert poring.element == {:water, 1}
    end

    test "loads mob by aegis name" do
      assert {:ok, poring} = MobManagement.get_mob_by_name(:PORING)
      assert poring.id == 1002
    end

    test "returns error for non-existent mob" do
      assert {:error, :mob_not_found} = MobManagement.get_mob_by_id(99_999)
      assert {:error, :mob_not_found} = MobManagement.get_mob_by_name(:NON_EXISTENT)
    end

    test "loads all mobs" do
      mobs = MobManagement.get_all_mobs()
      assert length(mobs) > 0
      assert Enum.all?(mobs, &match?(%MobDefinition{}, &1))
    end
  end

  describe "spawn data loading" do
    test "loads spawn data for prt_fild08" do
      assert {:ok, spawns} = MobManagement.get_spawns_for_map("prt_fild08")
      assert length(spawns) > 0

      # Check for Poring spawn
      poring_spawns = Enum.filter(spawns, &(&1.mob_id == 1002))
      assert length(poring_spawns) > 0
    end

    test "returns error for map with no spawns" do
      assert {:error, :no_spawns} = MobManagement.get_spawns_for_map("non_existent_map")
    end

    test "loads all spawn data" do
      all_spawns = MobManagement.get_all_spawns()
      assert map_size(all_spawns) > 0
      assert Map.has_key?(all_spawns, "prt_fild08")
    end
  end

  describe "mob calculations" do
    setup do
      {:ok, poring} = MobManagement.get_mob_by_id(1002)
      {:ok, poring: poring}
    end

    test "calculates attack", %{poring: poring} do
      # Poring has atk_min: 1, atk_max: 1
      assert MobManagement.calculate_attack(poring) == 1
    end

    test "calculates hit rate", %{poring: poring} do
      # Level 1 + Dex 6 = 7
      assert MobManagement.calculate_hit_rate(poring) == 7
    end

    test "calculates flee rate", %{poring: poring} do
      # Level 1 + Agi 1 = 2
      assert MobManagement.calculate_flee_rate(poring) == 2
    end

    test "checks if mob is aggressive", %{poring: poring} do
      # Poring has ai_type: 2, which is not aggressive
      assert MobManagement.aggressive?(poring) == false
    end

    test "checks if mob can move", %{poring: poring} do
      # Poring has no movement restrictions
      assert MobManagement.can_move?(poring) == true
    end

    test "calculates element modifier", %{poring: poring} do
      # Poring is Water element
      # Water resists Fire
      assert MobManagement.get_element_modifier(poring, :fire, 1) == 0.5
      # Same element
      assert MobManagement.get_element_modifier(poring, :water, 1) == 0.5
      # Neutral
      assert MobManagement.get_element_modifier(poring, :earth, 1) == 1.0
    end

    test "calculates experience modifier" do
      # Same level
      assert MobManagement.calculate_exp_modifier(10, 10) == 1.0
      # 5 level difference
      assert MobManagement.calculate_exp_modifier(10, 15) == 1.0
      # 10 level difference
      assert MobManagement.calculate_exp_modifier(10, 20) == 0.9
    end

    test "calculates drop rate" do
      assert MobManagement.calculate_drop_rate(1000, 1.0) == 1000
      assert MobManagement.calculate_drop_rate(1000, 2.0) == 2000
      assert MobManagement.calculate_drop_rate(1000, 0.5) == 500
    end
  end

  describe "spawn position calculation" do
    test "gets random spawn position for entire map" do
      spawn_area = %MobManagement.MobSpawn.SpawnArea{x: 0, y: 0, xs: 0, ys: 0}

      {:ok, {x, y}} = MobManagement.get_random_spawn_position(spawn_area, {512, 512})
      assert x >= 0 and x < 512
      assert y >= 0 and y < 512
    end

    test "gets random spawn position for specific area" do
      spawn_area = %MobManagement.MobSpawn.SpawnArea{x: 100, y: 100, xs: 10, ys: 10}

      {:ok, {x, y}} = MobManagement.get_random_spawn_position(spawn_area, {512, 512})
      assert x >= 90 and x <= 110
      assert y >= 90 and y <= 110
    end

    test "returns error for invalid spawn area" do
      spawn_area = %MobManagement.MobSpawn.SpawnArea{x: 600, y: 600, xs: 10, ys: 10}

      assert {:error, :invalid_spawn_area} =
               MobManagement.get_random_spawn_position(spawn_area, {512, 512})
    end
  end
end
